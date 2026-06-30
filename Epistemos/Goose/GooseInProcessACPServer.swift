import CryptoKit
import Foundation
import Network
import os

@MainActor
protocol GooseMASPromptStreaming: AnyObject {
    func streamGooseMASPrompt(
        prompt: String,
        systemPrompt: String?,
        maxTokens: Int
    ) -> AsyncThrowingStream<String, Error>
}

extension CloudLLMClient: GooseMASPromptStreaming {
    func streamGooseMASPrompt(
        prompt: String,
        systemPrompt: String?,
        maxTokens: Int
    ) -> AsyncThrowingStream<String, Error> {
        stream(prompt: prompt, systemPrompt: systemPrompt, maxTokens: maxTokens)
    }
}

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

    private final class WebSocketConnectionBox: @unchecked Sendable {
        let connection: NWConnection

        init(_ connection: NWConnection) {
            self.connection = connection
        }
    }

    private struct PromptRun: @unchecked Sendable {
        let requestID: Any?
        let sessionID: String
        let messageID: String
        let runID: String
        let created: Int
        let prompt: String
        let systemPrompt: String?
        let maxTokens: Int
    }

    private struct PromptStreamerBox: @unchecked Sendable {
        let streamer: (any GooseMASPromptStreaming)?
    }

    private static let logger = Logger(subsystem: "com.epistemos.goose", category: "GooseInProcessACPServer")
    private static let maxHTTPRequestBytes = 256 * 1024
    private static let maxWebSocketBufferBytes = 2 * 1024 * 1024
    private static let defaultPromptMaxTokens = 4_096

    private let secretKey: String
    private let catalog: GooseMASAgentCoreCatalog
    private let promptStreamer: PromptStreamerBox
    private let queue = DispatchQueue(label: "com.epistemos.goose.inprocess-acp", qos: .userInitiated)
    private var configValues: [String: Any] = [:]
    private let statusLock = NSLock()
    private var _status: Status = .idle
    private var listener: NWListener?
    private var sessions: [String: Session] = [:]

    var status: Status { statusLock.withLock { _status } }

    init(
        secretKey: String,
        catalog: GooseMASAgentCoreCatalog = .load(),
        promptStreamer: (any GooseMASPromptStreaming)? = nil
    ) {
        self.secretKey = secretKey
        self.catalog = catalog
        self.promptStreamer = PromptStreamerBox(streamer: promptStreamer)
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
        case ("OPTIONS", _):
            sendHTTP(connection, GooseInProcessACPHTTPRequest.response(status: 204, body: ""))
        case ("GET", "/health"), ("HEAD", "/health"):
            let body = method == "HEAD" ? "" : "ok"
            sendHTTP(connection, GooseInProcessACPHTTPRequest.response(status: 200, body: body))
        case ("GET", "/status"), ("HEAD", "/status"):
            let body = method == "HEAD" ? "" : "ok"
            sendHTTP(connection, GooseInProcessACPHTTPRequest.response(status: 200, body: body))
        case ("GET", "/acp"):
            upgradeToWebSocket(request, on: connection)
        case ("GET", "/config"):
            guard authorizeREST(request, on: connection) else { return }
            sendHTTPJSON(connection, ["config": configValues])
        case ("POST", "/config/read"):
            guard authorizeREST(request, on: connection) else { return }
            let body = request.jsonBody()
            let key = body["key"] as? String ?? ""
            sendHTTPJSON(connection, configValues[key] ?? NSNull())
        case ("POST", "/config/upsert"):
            guard authorizeREST(request, on: connection) else { return }
            let body = request.jsonBody()
            if let key = body["key"] as? String, !key.isEmpty {
                configValues[key] = body["value"] ?? NSNull()
            }
            sendHTTPJSON(connection, ["ok": true])
        case ("POST", "/config/remove"):
            guard authorizeREST(request, on: connection) else { return }
            let body = request.jsonBody()
            if let key = body["key"] as? String {
                configValues.removeValue(forKey: key)
            }
            sendHTTPJSON(connection, ["ok": true])
        case ("GET", "/config/providers"):
            guard authorizeREST(request, on: connection) else { return }
            sendHTTPJSON(connection, restProviderDetails())
        case ("GET", "/config/provider-catalog"):
            guard authorizeREST(request, on: connection) else { return }
            sendHTTPJSON(connection, catalog.providerCatalogResult())
        case ("GET", "/config/extensions"):
            guard authorizeREST(request, on: connection) else { return }
            sendHTTPJSON(connection, ["extensions": [], "_meta": catalog.metadata()])
        case ("GET", "/features"):
            guard authorizeREST(request, on: connection) else { return }
            sendHTTPJSON(connection, ["features": ["masBoundedGoose": true], "_meta": catalog.metadata()])
        default:
            sendHTTP(connection, GooseInProcessACPHTTPRequest.response(status: 404, body: "not found"))
        }
    }

    private func sendHTTP(_ connection: NWConnection, _ data: Data) {
        connection.send(content: data, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    private func sendHTTPJSON(_ connection: NWConnection, _ object: Any, status: Int = 200) {
        guard JSONSerialization.isValidJSONObject(object) || object is NSNull || object is String || object is Bool || object is NSNumber else {
            sendHTTP(connection, GooseInProcessACPHTTPRequest.jsonResponse(
                status: 500,
                object: ["error": "invalid json response"]
            ))
            return
        }
        sendHTTP(connection, GooseInProcessACPHTTPRequest.jsonResponse(status: status, object: object))
    }

    private func authorizeREST(_ request: GooseInProcessACPHTTPRequest, on connection: NWConnection) -> Bool {
        guard request.header("x-secret-key") == secretKey else {
            sendHTTPJSON(connection, ["error": "unauthorized"], status: 401)
            return false
        }
        return true
    }

    private func restProviderDetails() -> [[String: Any]] {
        catalog.providers.map { provider in
            [
                "name": provider.providerId,
                "display_name": provider.providerName,
                "description": provider.description,
                "configured": provider.configured,
                "metadata": [
                    "default_model": provider.defaultModel,
                    "models": provider.models.map { model in
                        [
                            "name": model.id,
                            "display_name": model.name,
                            "context_limit": model.contextLimit,
                            "supports_tools": true,
                        ] as [String: Any]
                    },
                ],
                "_meta": [
                    "masBounded": provider.masBounded,
                    "policyProfile": catalog.policyProfile,
                ],
            ] as [String: Any]
        }
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
            let box = WebSocketConnectionBox(connection)
            let replies = handleJSONRPC(text, on: box)
            sendJSONMessages(replies, on: box)
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

    private func sendJSONMessages(_ messages: [String], on box: WebSocketConnectionBox) {
        guard !messages.isEmpty else { return }
        let frames = messages.map { GooseInProcessACPFraming.textFrame($0) }
        queue.async { [weak self] in
            self?.sendWebSocketFrames(frames, on: box.connection)
        }
    }

    private func handleJSONRPC(_ text: String, on box: WebSocketConnectionBox) -> [String] {
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
            let run = makePromptRun(id: id, params: params)
            beginPromptRun(run, on: box)
            return [
                Self.jsonNotification(
                    method: "session/update",
                    params: [
                        "sessionId": run.sessionID,
                        "update": [
                            "sessionUpdate": "session_info_update",
                            "_meta": [
                                "goose": [
                                    "activeRunId": run.runID,
                                ],
                            ],
                        ],
                    ]
                ),
            ]
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

    private func makePromptRun(id: Any?, params: [String: Any]) -> PromptRun {
        let sessionID = params["sessionId"] as? String ?? Self.newSessionID()
        if sessions[sessionID] == nil {
            sessions[sessionID] = Session(id: sessionID, createdAt: Date(), cwd: NSHomeDirectory())
        }
        return PromptRun(
            requestID: id,
            sessionID: sessionID,
            messageID: "mas_msg_\(UUID().uuidString.lowercased())",
            runID: "mas_run_\(UUID().uuidString.lowercased())",
            created: Int(Date().timeIntervalSince1970),
            prompt: Self.promptText(from: params),
            systemPrompt: Self.systemPrompt(from: params),
            maxTokens: Self.maxTokens(from: params)
        )
    }

    private func beginPromptRun(_ run: PromptRun, on box: WebSocketConnectionBox) {
        guard !run.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            finishPromptRun(
                run,
                on: box,
                errorMessage: "No prompt content was supplied to the MAS in-process backend."
            )
            return
        }
        let streamerBox = promptStreamer
        guard streamerBox.streamer != nil else {
            finishPromptRun(
                run,
                on: box,
                errorMessage: "No configured cloud model client is available for the MAS in-process backend."
            )
            return
        }

        Task { [weak self, box, run, streamerBox] in
            guard let self else { return }
            var outputUTF8Bytes = 0
            do {
                guard let streamer = streamerBox.streamer else {
                    self.finishPromptRun(
                        run,
                        on: box,
                        errorMessage: "No configured cloud model client is available for the MAS in-process backend."
                    )
                    return
                }
                let stream = await streamer.streamGooseMASPrompt(
                    prompt: run.prompt,
                    systemPrompt: run.systemPrompt,
                    maxTokens: run.maxTokens
                )
                for try await chunk in stream {
                    if Task.isCancelled {
                        self.finishPromptRun(run, on: box, stopReason: "cancelled", outputUTF8Bytes: outputUTF8Bytes)
                        return
                    }
                    guard !chunk.isEmpty else { continue }
                    outputUTF8Bytes += chunk.utf8.count
                    self.sendJSONMessages([
                        Self.agentMessageChunk(
                            sessionID: run.sessionID,
                            messageID: run.messageID,
                            created: run.created,
                            text: chunk
                        ),
                    ], on: box)
                }
                self.finishPromptRun(run, on: box, stopReason: "end_turn", outputUTF8Bytes: outputUTF8Bytes)
            } catch {
                let message = EngineLogDiagnostics.logMessage(
                    for: error,
                    fallback: "MAS in-process backend prompt failed"
                )
                self.finishPromptRun(run, on: box, errorMessage: message)
            }
        }
    }

    private func finishPromptRun(
        _ run: PromptRun,
        on box: WebSocketConnectionBox,
        stopReason: String,
        outputUTF8Bytes: Int
    ) {
        let approxOutputTokens = max(0, outputUTF8Bytes / 4)
        let approxInputTokens = max(0, run.prompt.utf8.count / 4)
        sendJSONMessages([
            Self.clearActiveRunNotification(sessionID: run.sessionID),
            Self.usageNotification(
                sessionID: run.sessionID,
                inputTokens: approxInputTokens,
                outputTokens: approxOutputTokens
            ),
            Self.jsonResponse(
                id: run.requestID,
                result: [
                    "stopReason": stopReason,
                    "usage": [
                        "inputTokens": approxInputTokens,
                        "outputTokens": approxOutputTokens,
                        "totalTokens": approxInputTokens + approxOutputTokens,
                    ],
                    "_meta": catalog.metadata(),
                ]
            ),
        ], on: box)
    }

    private func finishPromptRun(
        _ run: PromptRun,
        on box: WebSocketConnectionBox,
        errorMessage: String
    ) {
        sendJSONMessages([
            Self.agentMessageChunk(
                sessionID: run.sessionID,
                messageID: run.messageID,
                created: run.created,
                text: "MAS backend could not run this prompt: \(errorMessage)"
            ),
            Self.clearActiveRunNotification(sessionID: run.sessionID),
            Self.jsonError(
                id: run.requestID,
                code: -32041,
                message: errorMessage,
                data: [
                    "backend": "agent_core",
                    "policyProfile": catalog.policyProfile,
                    "masBounded": true,
                ]
            ),
        ], on: box)
    }

    private static func promptText(from params: [String: Any]) -> String {
        if let text = params["text"] as? String {
            return text
        }
        if let message = params["message"] as? String {
            return message
        }
        if let prompt = params["prompt"] as? String {
            return prompt
        }
        guard let blocks = params["prompt"] as? [[String: Any]] else {
            return ""
        }
        let parts = blocks.compactMap { block -> String? in
            guard (block["type"] as? String) == "text" else { return nil }
            return block["text"] as? String
        }
        return parts.joined(separator: "\n")
    }

    private static func systemPrompt(from params: [String: Any]) -> String? {
        if let systemPrompt = params["systemPrompt"] as? String {
            return systemPrompt
        }
        if let systemPrompt = params["system"] as? String {
            return systemPrompt
        }
        return """
        You are Epistemos Goose running in the App Store MAS backend. Stay within the bounded sandbox profile: hosted model APIs, security-scoped vault files, network HTTP, and in-app capabilities are allowed. Shell commands, dependency installers, local stdio MCP, and subprocess-backed Goose developer tools are Pro-only.
        """
    }

    private static func maxTokens(from params: [String: Any]) -> Int {
        let value = (params["maxTokens"] as? Int)
            ?? (params["max_tokens"] as? Int)
            ?? defaultPromptMaxTokens
        return min(max(value, 1), 16_384)
    }

    private static func agentMessageChunk(
        sessionID: String,
        messageID: String,
        created: Int,
        text: String
    ) -> String {
        jsonNotification(
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
        )
    }

    private static func clearActiveRunNotification(sessionID: String) -> String {
        jsonNotification(
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
        )
    }

    private static func usageNotification(
        sessionID: String,
        inputTokens: Int,
        outputTokens: Int
    ) -> String {
        jsonNotification(
            method: "session/update",
            params: [
                "sessionId": sessionID,
                "update": [
                    "sessionUpdate": "usage_update",
                    "size": inputTokens + outputTokens,
                    "used": inputTokens + outputTokens,
                    "cost": [
                        "amount": 0,
                        "currency": "USD",
                    ],
                ],
            ]
        )
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
    let body: Data

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

    func jsonBody() -> [String: Any] {
        guard !body.isEmpty,
              let object = try? JSONSerialization.jsonObject(with: body) as? [String: Any] else {
            return [:]
        }
        return object
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
        let contentLength: Int
        if let rawContentLength = headers["content-length"] {
            guard let parsedContentLength = Int(rawContentLength),
                  parsedContentLength >= 0 else {
                return .invalid
            }
            contentLength = parsedContentLength
        } else {
            contentLength = 0
        }
        let bodyStart = range.upperBound
        guard buffer.count >= bodyStart + contentLength else { return .needMore }
        let body = contentLength > 0
            ? buffer.subdata(in: bodyStart..<(bodyStart + contentLength))
            : Data()
        return .complete(Self(method: method, target: target, path: path, headers: headers, body: body))
    }

    static func response(status: Int, body: String) -> Data {
        response(status: status, body: Data(body.utf8), contentType: "text/plain; charset=utf-8")
    }

    static func jsonResponse(status: Int, object: Any) -> Data {
        let data = (try? JSONSerialization.data(
            withJSONObject: object,
            options: [.fragmentsAllowed]
        )) ?? Data("null".utf8)
        return response(status: status, body: data, contentType: "application/json; charset=utf-8")
    }

    static func response(status: Int, body bodyData: Data, contentType: String) -> Data {
        let reason: String
        switch status {
        case 204: reason = "No Content"
        case 200: reason = "OK"
        case 400: reason = "Bad Request"
        case 401: reason = "Unauthorized"
        case 404: reason = "Not Found"
        case 413: reason = "Payload Too Large"
        default: reason = "Error"
        }
        var response = Data()
        response.append(Data("HTTP/1.1 \(status) \(reason)\r\n".utf8))
        response.append(Data("Content-Type: \(contentType)\r\n".utf8))
        response.append(Data("Content-Length: \(bodyData.count)\r\n".utf8))
        response.append(Data("Access-Control-Allow-Origin: *\r\n".utf8))
        response.append(Data("Access-Control-Allow-Headers: Content-Type, X-Secret-Key\r\n".utf8))
        response.append(Data("Access-Control-Allow-Methods: GET, POST, OPTIONS\r\n".utf8))
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
