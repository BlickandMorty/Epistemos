import CryptoKit
import Foundation
import Network
import os

nonisolated final class GooseInProcessACPServer: @unchecked Sendable {
    enum Status: Equatable, Sendable {
        case idle
        case starting
        case running(baseURL: URL)
        case failed(String)
        case stopped
    }

    private struct Session {
        let id: String
        let createdAt: Date
        let cwd: String
    }

    private static let logger = Logger(subsystem: "com.epistemos.goose", category: "GooseInProcessACPServer")
    private static let maxHTTPRequestBytes = 256 * 1024
    private static let maxWebSocketBufferBytes = 2 * 1024 * 1024

    private let secretKey: String
    private let catalog: GooseMASAgentCoreCatalog
    private let queue = DispatchQueue(label: "com.epistemos.goose.inprocess-acp", qos: .userInitiated)
    private let statusLock = NSLock()
    private var _status: Status = .idle
    private var listener: NWListener?
    private var sessions: [String: Session] = [:]

    var status: Status { statusLock.withLock { _status } }

    init(secretKey: String, catalog: GooseMASAgentCoreCatalog = .load()) {
        self.secretKey = secretKey
        self.catalog = catalog
    }

    func start() throws {
        guard listener == nil else { return }
        let params = NWParameters.tcp
        params.requiredInterfaceType = .loopback
        params.allowLocalEndpointReuse = true

        let listener = try NWListener(using: params)
        listener.newConnectionHandler = { [weak self] connection in
            self?.accept(connection)
        }
        listener.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            switch state {
            case .ready:
                guard let port = listener.port?.rawValue,
                      let baseURL = URL(string: "http://127.0.0.1:\(port)/") else {
                    self.setStatus(.failed("in-process ACP listener ready but no bound port"))
                    return
                }
                self.setStatus(.running(baseURL: baseURL))
                Self.logger.info("Goose in-process ACP ready on 127.0.0.1:\(port, privacy: .public)")
            case .failed(let error):
                let message = EngineLogDiagnostics.logMessage(
                    for: error,
                    fallback: "Goose in-process ACP listener failed"
                )
                Self.logger.error("\(message, privacy: .public)")
                self.setStatus(.failed(message))
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

    private func setStatus(_ status: Status) {
        statusLock.withLock { _status = status }
    }

    private func accept(_ connection: NWConnection) {
        connection.start(queue: queue)
        receiveHTTP(connection, accumulated: Data())
    }

    private func receiveHTTP(_ connection: NWConnection, accumulated: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            if let error {
                let message = EngineLogDiagnostics.logMessage(for: error, fallback: "ACP HTTP receive failed")
                Self.logger.debug("\(message, privacy: .public)")
                connection.cancel()
                return
            }

            var buffer = accumulated
            if let data { buffer.append(data) }
            if buffer.count > Self.maxHTTPRequestBytes {
                self.sendHTTP(connection, GooseInProcessACPHTTPRequest.response(status: 413, body: "request too large"))
                return
            }

            switch GooseInProcessACPHTTPRequest.parse(buffer) {
            case .needMore:
                if isComplete {
                    connection.cancel()
                } else {
                    self.receiveHTTP(connection, accumulated: buffer)
                }
            case .invalid:
                self.sendHTTP(connection, GooseInProcessACPHTTPRequest.response(status: 400, body: "bad request"))
            case .complete(let request):
                self.handle(request, on: connection)
            }
        }
    }

    private func handle(_ request: GooseInProcessACPHTTPRequest, on connection: NWConnection) {
        let method = request.method.uppercased()
        switch (method, request.path) {
        case ("GET", "/health"), ("HEAD", "/health"):
            let body = method == "HEAD" ? "" : "ok"
            sendHTTP(connection, GooseInProcessACPHTTPRequest.response(status: 200, body: body))
        case ("GET", "/status"), ("HEAD", "/status"):
            let body = method == "HEAD" ? "" : "ok"
            sendHTTP(connection, GooseInProcessACPHTTPRequest.response(status: 200, body: body))
        case ("GET", "/acp"):
            upgradeToWebSocket(request, on: connection)
        default:
            sendHTTP(connection, GooseInProcessACPHTTPRequest.response(status: 404, body: "not found"))
        }
    }

    private func sendHTTP(_ connection: NWConnection, _ data: Data) {
        connection.send(content: data, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    private func upgradeToWebSocket(_ request: GooseInProcessACPHTTPRequest, on connection: NWConnection) {
        guard request.queryItem(named: "token") == secretKey else {
            sendHTTP(connection, GooseInProcessACPHTTPRequest.response(status: 401, body: "unauthorized"))
            return
        }
        guard request.header("upgrade")?.lowercased() == "websocket",
              request.header("connection")?.lowercased().contains("upgrade") == true,
              let key = request.header("sec-websocket-key") else {
            sendHTTP(connection, GooseInProcessACPHTTPRequest.response(status: 400, body: "bad websocket upgrade"))
            return
        }

        let acceptKey = GooseInProcessACPFraming.webSocketAcceptKey(for: key)
        let response = """
        HTTP/1.1 101 Switching Protocols\r
        Upgrade: websocket\r
        Connection: Upgrade\r
        Sec-WebSocket-Accept: \(acceptKey)\r
        \r

        """
        connection.send(content: Data(response.utf8), completion: .contentProcessed { [weak self] error in
            guard let self else { return }
            if let error {
                let message = EngineLogDiagnostics.logMessage(for: error, fallback: "ACP websocket upgrade failed")
                Self.logger.debug("\(message, privacy: .public)")
                connection.cancel()
                return
            }
            self.receiveWebSocket(connection, accumulated: Data())
        })
    }

    private func receiveWebSocket(_ connection: NWConnection, accumulated: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            if let error {
                let message = EngineLogDiagnostics.logMessage(for: error, fallback: "ACP websocket receive failed")
                Self.logger.debug("\(message, privacy: .public)")
                connection.cancel()
                return
            }

            var buffer = accumulated
            if let data { buffer.append(data) }
            if buffer.count > Self.maxWebSocketBufferBytes {
                self.sendWebSocketFrames(
                    [GooseInProcessACPFraming.closeFrame(code: 1009, reason: "frame too large")],
                    on: connection,
                    closeWhenDone: true
                )
                return
            }

            self.drainWebSocketBuffer(buffer, on: connection, isComplete: isComplete)
        }
    }

    private func drainWebSocketBuffer(_ buffer: Data, on connection: NWConnection, isComplete: Bool) {
        var remaining = buffer
        while !remaining.isEmpty {
            switch GooseInProcessACPFraming.parseClientFrame(remaining) {
            case .needMore:
                if isComplete {
                    connection.cancel()
                } else {
                    receiveWebSocket(connection, accumulated: remaining)
                }
                return
            case .invalid:
                sendWebSocketFrames(
                    [GooseInProcessACPFraming.closeFrame(code: 1002, reason: "bad frame")],
                    on: connection,
                    closeWhenDone: true
                )
                return
            case .tooLarge:
                sendWebSocketFrames(
                    [GooseInProcessACPFraming.closeFrame(code: 1009, reason: "frame too large")],
                    on: connection,
                    closeWhenDone: true
                )
                return
            case .complete(let frame, let consumed):
                remaining.removeFirst(consumed)
                handle(frame, on: connection)
            }
        }
        receiveWebSocket(connection, accumulated: Data())
    }

    private func handle(_ frame: GooseInProcessACPFraming.Frame, on connection: NWConnection) {
        switch frame.opcode {
        case 0x1:
            guard let text = String(data: frame.payload, encoding: .utf8) else {
                sendWebSocketFrames(
                    [GooseInProcessACPFraming.closeFrame(code: 1007, reason: "invalid utf8")],
                    on: connection,
                    closeWhenDone: true
                )
                return
            }
            let replies = handleJSONRPC(text)
            sendWebSocketFrames(replies.map { GooseInProcessACPFraming.textFrame($0) }, on: connection)
        case 0x8:
            sendWebSocketFrames([GooseInProcessACPFraming.closeFrame()], on: connection, closeWhenDone: true)
        case 0x9:
            sendWebSocketFrames([GooseInProcessACPFraming.frame(opcode: 0xA, payload: frame.payload)], on: connection)
        default:
            sendWebSocketFrames(
                [GooseInProcessACPFraming.closeFrame(code: 1003, reason: "unsupported frame")],
                on: connection,
                closeWhenDone: true
            )
        }
    }

    private func sendWebSocketFrames(_ frames: [Data], on connection: NWConnection, closeWhenDone: Bool = false) {
        guard let first = frames.first else {
            if closeWhenDone { connection.cancel() }
            return
        }
        let rest = Array(frames.dropFirst())
        connection.send(content: first, completion: .contentProcessed { [weak self] _ in
            guard let self else { return }
            self.sendWebSocketFrames(rest, on: connection, closeWhenDone: closeWhenDone)
        })
    }

    private func handleJSONRPC(_ text: String) -> [String] {
        guard let data = text.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              object["jsonrpc"] as? String == "2.0" else {
            return [Self.jsonError(id: nil, code: -32700, message: "Parse error")]
        }
        guard let method = object["method"] as? String else {
            return [Self.jsonError(id: Self.requestID(from: object), code: -32600, message: "Invalid request")]
        }

        let id = Self.requestID(from: object)
        let params = object["params"] as? [String: Any] ?? [:]
        switch method {
        case "initialize":
            return [Self.jsonResponse(id: id, result: catalog.initializeResult())]
        case "session/new":
            let sessionID = Self.newSessionID()
            let cwd = params["cwd"] as? String ?? NSHomeDirectory()
            sessions[sessionID] = Session(id: sessionID, createdAt: Date(), cwd: cwd)
            return [Self.jsonResponse(id: id, result: ["sessionId": sessionID])]
        case "session/list":
            return [Self.jsonResponse(id: id, result: listSessionsResult())]
        case "session/load":
            let sessionID = params["sessionId"] as? String ?? Self.newSessionID()
            if sessions[sessionID] == nil {
                sessions[sessionID] = Session(
                    id: sessionID,
                    createdAt: Date(),
                    cwd: params["cwd"] as? String ?? NSHomeDirectory()
                )
            }
            return [Self.jsonResponse(id: id, result: sessionStateResult())]
        case "session/fork":
            let sessionID = Self.newSessionID()
            sessions[sessionID] = Session(
                id: sessionID,
                createdAt: Date(),
                cwd: params["cwd"] as? String ?? NSHomeDirectory()
            )
            var result = sessionStateResult()
            result["sessionId"] = sessionID
            return [Self.jsonResponse(id: id, result: result)]
        case "session/prompt":
            return promptResponses(id: id, params: params)
        case "session/cancel", "session/close":
            if let sessionID = params["sessionId"] as? String {
                sessions.removeValue(forKey: sessionID)
            }
            return [Self.jsonResponse(id: id, result: ["ok": true])]
        case "_goose/unstable/providers/list":
            return [Self.jsonResponse(id: id, result: catalog.providersResult())]
        case "_goose/unstable/providers/catalog/list",
             "_goose/unstable/providers/setup/catalog/list":
            return [Self.jsonResponse(id: id, result: catalog.providerCatalogResult())]
        case "_goose/unstable/providers/config/status":
            return [Self.jsonResponse(id: id, result: catalog.providerStatusResult())]
        case "_goose/unstable/config/extensions/list",
             "_goose/unstable/extensions/list":
            return [Self.jsonResponse(id: id, result: catalog.extensionsResult())]
        case "_goose/unstable/sources/list",
             "_goose/unstable/recipes/list",
             "_goose/unstable/schedules/list",
             "_goose/unstable/skills/list":
            return [Self.jsonResponse(id: id, result: emptySourcesResult())]
        default:
            if Self.isProGated(method: method) {
                return [
                    Self.jsonError(
                        id: id,
                        code: -32040,
                        message: "Capability is Pro-only in the App Store build.",
                        data: catalog.unsupportedCapabilityData(capability: method)
                    ),
                ]
            }
            return [
                Self.jsonError(
                    id: id,
                    code: -32601,
                    message: "Method not found",
                    data: [
                        "method": method,
                        "backend": "agent_core",
                        "policyProfile": catalog.policyProfile,
                    ]
                ),
            ]
        }
    }

    private func listSessionsResult() -> [String: Any] {
        let items = sessions.values
            .sorted { $0.createdAt > $1.createdAt }
            .map { session in
                [
                    "id": session.id,
                    "sessionId": session.id,
                    "title": "Epistemos MAS Session",
                    "cwd": session.cwd,
                    "modified": Int(session.createdAt.timeIntervalSince1970),
                    "created": Int(session.createdAt.timeIntervalSince1970),
                ] as [String: Any]
            }
        return [
            "sessions": items,
            "nextCursor": NSNull(),
            "_meta": catalog.metadata(),
        ]
    }

    private func sessionStateResult() -> [String: Any] {
        [
            "modes": [
                "current": "chat",
                "available": ["chat"],
            ],
            "models": [
                "providers": catalog.providersResult()["entries"] ?? [],
            ],
            "configOptions": [
                "masBounded": true,
                "proGatedCapabilities": catalog.proGatedCapabilities.map { $0.jsonObject() },
            ],
            "_meta": catalog.metadata(),
        ]
    }

    private func emptySourcesResult() -> [String: Any] {
        [
            "sources": [],
            "items": [],
            "entries": [],
            "_meta": catalog.metadata(),
        ]
    }

    private func promptResponses(id: Any?, params: [String: Any]) -> [String] {
        let sessionID = params["sessionId"] as? String ?? Self.newSessionID()
        if sessions[sessionID] == nil {
            sessions[sessionID] = Session(id: sessionID, createdAt: Date(), cwd: NSHomeDirectory())
        }
        let messageID = "mas_msg_\(UUID().uuidString.lowercased())"
        let runID = "mas_run_\(UUID().uuidString.lowercased())"
        let created = Int(Date().timeIntervalSince1970)
        let text = """
        Epistemos MAS in-process backend is connected. This App Store backend is bounded: vault files, hosted model APIs, network HTTP, and in-app tools are allowed. Developer shell, install-deps, local stdio MCP, and the goose serve subprocess are Pro-only.
        """

        return [
            Self.jsonNotification(
                method: "session/update",
                params: [
                    "sessionId": sessionID,
                    "update": [
                        "sessionUpdate": "session_info_update",
                        "_meta": [
                            "goose": [
                                "activeRunId": runID,
                            ],
                        ],
                    ],
                ]
            ),
            Self.jsonNotification(
                method: "session/update",
                params: [
                    "sessionId": sessionID,
                    "update": [
                        "sessionUpdate": "agent_message_chunk",
                        "content": [
                            "type": "text",
                            "text": text,
                        ],
                        "_meta": [
                            "goose": [
                                "created": created,
                                "messageId": messageID,
                            ],
                        ],
                    ],
                ]
            ),
            Self.jsonNotification(
                method: "session/update",
                params: [
                    "sessionId": sessionID,
                    "update": [
                        "sessionUpdate": "session_info_update",
                        "_meta": [
                            "goose": [
                                "activeRunId": NSNull(),
                            ],
                        ],
                    ],
                ]
            ),
            Self.jsonNotification(
                method: "session/update",
                params: [
                    "sessionId": sessionID,
                    "update": [
                        "sessionUpdate": "usage_update",
                        "size": 0,
                        "used": 0,
                        "cost": [
                            "amount": 0,
                            "currency": "USD",
                        ],
                    ],
                ]
            ),
            Self.jsonResponse(
                id: id,
                result: [
                    "stopReason": "end_turn",
                    "usage": [
                        "inputTokens": 0,
                        "outputTokens": 0,
                        "totalTokens": 0,
                    ],
                ]
            ),
        ]
    }

    private static func requestID(from object: [String: Any]) -> Any? {
        guard let id = object["id"] else { return nil }
        return id is NSNull ? nil : id
    }

    private static func isProGated(method: String) -> Bool {
        let lower = method.lowercased()
        return lower.contains("developer")
            || lower.contains("shell")
            || lower.contains("stdio")
            || lower.contains("install")
            || lower.contains("subprocess")
            || lower.contains("terminal")
    }

    private static func newSessionID() -> String {
        "mas_\(UUID().uuidString.lowercased())"
    }

    private static func jsonResponse(id: Any?, result: [String: Any]) -> String {
        serializeJSON([
            "jsonrpc": "2.0",
            "id": id ?? NSNull(),
            "result": result,
        ])
    }

    private static func jsonNotification(method: String, params: [String: Any]) -> String {
        serializeJSON([
            "jsonrpc": "2.0",
            "method": method,
            "params": params,
        ])
    }

    private static func jsonError(
        id: Any?,
        code: Int,
        message: String,
        data: [String: Any]? = nil
    ) -> String {
        var error: [String: Any] = [
            "code": code,
            "message": message,
        ]
        if let data { error["data"] = data }
        return serializeJSON([
            "jsonrpc": "2.0",
            "id": id ?? NSNull(),
            "error": error,
        ])
    }

    private static func serializeJSON(_ object: [String: Any]) -> String {
        guard JSONSerialization.isValidJSONObject(object),
              let data = try? JSONSerialization.data(withJSONObject: object),
              let text = String(data: data, encoding: .utf8) else {
            return #"{"jsonrpc":"2.0","id":null,"error":{"code":-32603,"message":"Internal error"}}"#
        }
        return text
    }
}

nonisolated enum GooseInProcessACPFraming {
    struct Frame: Equatable, Sendable {
        let opcode: UInt8
        let payload: Data
    }

    enum ParseResult: Equatable {
        case needMore
        case invalid
        case tooLarge
        case complete(Frame, consumed: Int)
    }

    private static let webSocketGUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
    private static let maxFramePayloadBytes = 1024 * 1024

    static func webSocketAcceptKey(for key: String) -> String {
        let digest = Insecure.SHA1.hash(data: Data((key + webSocketGUID).utf8))
        return Data(digest).base64EncodedString()
    }

    static func textFrame(_ text: String) -> Data {
        frame(opcode: 0x1, payload: Data(text.utf8))
    }

    static func closeFrame(code: UInt16 = 1000, reason: String = "") -> Data {
        var payload = Data()
        payload.append(UInt8(code >> 8))
        payload.append(UInt8(code & 0xFF))
        payload.append(Data(reason.utf8))
        return frame(opcode: 0x8, payload: payload)
    }

    static func frame(opcode: UInt8, payload: Data) -> Data {
        var bytes = Data()
        bytes.append(0x80 | (opcode & 0x0F))
        if payload.count < 126 {
            bytes.append(UInt8(payload.count))
        } else if payload.count <= UInt16.max {
            bytes.append(126)
            bytes.append(UInt8((payload.count >> 8) & 0xFF))
            bytes.append(UInt8(payload.count & 0xFF))
        } else {
            bytes.append(127)
            let value = UInt64(payload.count)
            for shift in stride(from: 56, through: 0, by: -8) {
                bytes.append(UInt8((value >> UInt64(shift)) & 0xFF))
            }
        }
        bytes.append(payload)
        return bytes
    }

    static func parseClientFrame(_ data: Data) -> ParseResult {
        guard data.count >= 2 else { return .needMore }
        let bytes = [UInt8](data)
        let first = bytes[0]
        let second = bytes[1]
        let fin = (first & 0x80) != 0
        let opcode = first & 0x0F
        guard fin else { return .invalid }
        guard [0x1, 0x8, 0x9].contains(opcode) else { return .invalid }
        guard (second & 0x80) != 0 else { return .invalid }

        var offset = 2
        var length = Int(second & 0x7F)
        if length == 126 {
            guard bytes.count >= offset + 2 else { return .needMore }
            length = (Int(bytes[offset]) << 8) | Int(bytes[offset + 1])
            offset += 2
        } else if length == 127 {
            guard bytes.count >= offset + 8 else { return .needMore }
            var value: UInt64 = 0
            for index in 0..<8 {
                value = (value << 8) | UInt64(bytes[offset + index])
            }
            guard value <= UInt64(Int.max) else { return .tooLarge }
            length = Int(value)
            offset += 8
        }

        guard length <= maxFramePayloadBytes else { return .tooLarge }
        guard bytes.count >= offset + 4 + length else { return .needMore }
        let mask = Array(bytes[offset..<offset + 4])
        offset += 4
        var payload = Data()
        payload.reserveCapacity(length)
        for index in 0..<length {
            payload.append(bytes[offset + index] ^ mask[index % 4])
        }
        return .complete(Frame(opcode: opcode, payload: payload), consumed: offset + length)
    }
}

nonisolated struct GooseInProcessACPHTTPRequest: Equatable, Sendable {
    let method: String
    let target: String
    let path: String
    let headers: [String: String]

    enum ParseResult: Equatable {
        case needMore
        case invalid
        case complete(GooseInProcessACPHTTPRequest)
    }

    func header(_ name: String) -> String? {
        headers[name.lowercased()]
    }

    func queryItem(named name: String) -> String? {
        guard let components = URLComponents(string: "http://127.0.0.1\(target)") else {
            return nil
        }
        return components.queryItems?.first { $0.name == name }?.value
    }

    static func parse(_ buffer: Data) -> ParseResult {
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
        let target = String(requestParts[1])
        let path = target.split(separator: "?", maxSplits: 1).first.map(String.init) ?? target
        var headers: [String: String] = [:]
        for line in lines where !line.isEmpty {
            guard let colon = line.firstIndex(of: ":") else { continue }
            let key = line[line.startIndex..<colon].trimmingCharacters(in: .whitespaces).lowercased()
            let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            headers[key] = value
        }
        return .complete(Self(method: method, target: target, path: path, headers: headers))
    }

    static func response(status: Int, body: String) -> Data {
        let reason: String
        switch status {
        case 200: reason = "OK"
        case 400: reason = "Bad Request"
        case 401: reason = "Unauthorized"
        case 404: reason = "Not Found"
        case 413: reason = "Payload Too Large"
        default: reason = "Error"
        }
        let bodyData = Data(body.utf8)
        var response = Data()
        response.append(Data("HTTP/1.1 \(status) \(reason)\r\n".utf8))
        response.append(Data("Content-Type: text/plain; charset=utf-8\r\n".utf8))
        response.append(Data("Content-Length: \(bodyData.count)\r\n".utf8))
        response.append(Data("Connection: close\r\n\r\n".utf8))
        response.append(bodyData)
        return response
    }
}

private extension Encodable {
    nonisolated func jsonObject() -> [String: Any] {
        guard let data = try? JSONEncoder().encode(self),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return [:]
        }
        return object
    }
}
