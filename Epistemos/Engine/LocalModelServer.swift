import Foundation
import Network
import os

// Loopback HTTP server exposing Epistemos's LOCAL models via an
// OpenAI/Ollama-compatible API. This is the "no-fork unlock": OpenCode, Codex,
// or any harness that speaks the OpenAI API can point at `http://127.0.0.1:<port>`
// and drive YOUR on-device Gemma/Qwen models — no fork, no duplicated agent loop.
//
// Design (osaurus-pattern, adapted to Network.framework since the app has no
// SwiftNIO dep):
//   - Binds 127.0.0.1 ONLY (`requiredInterfaceType = .loopback`) — never the
//     LAN. Needs `com.apple.security.network.server`.
//   - Decoupled from inference via injected closures (`generate` / `stream` /
//     `listModels`), wired in AppBootstrap. Keeps this file testable + free of
//     a hard dependency on the runtime stack.
//   - Flag-gated OFF (`EPISTEMOS_LOCAL_MODEL_SERVER_V0`). Honest-capability: it
//     exposes the SAME models the app routes to; it does not invent capability.
//
// First slice: GET /health, GET /v1/models (+ Ollama GET /api/tags), and
// POST /v1/chat/completions (OpenAI, non-streaming JSON + streaming SSE). Ollama
// /api/chat (NDJSON) + Anthropic /messages are follow-ups.
nonisolated final class LocalModelServer: @unchecked Sendable {
    static let flagKey = "EPISTEMOS_LOCAL_MODEL_SERVER_V0"

    /// The canonical loopback port for the osaurus-pattern OpenAI-compatible
    /// server (matches the `init` default + the Osaurus :1337 convention). Exposed
    /// so the Act-Osaurus bridge can publish the real endpoint without hardcoding.
    static let defaultPort: UInt16 = 1337

    static var isEnabled: Bool {
        if ProcessInfo.processInfo.environment[flagKey] == "1" { return true }
        return UserDefaults.standard.bool(forKey: flagKey)
    }

    struct ChatMessage: Sendable {
        let role: String
        let content: String
    }

    /// Non-streaming generation bridge: messages → full assistant text.
    typealias GenerateHandler = @Sendable (_ messages: [ChatMessage], _ model: String?, _ maxTokens: Int) async throws -> String
    /// Streaming generation bridge: messages → visible-text token stream.
    typealias StreamHandler = @Sendable (_ messages: [ChatMessage], _ model: String?, _ maxTokens: Int) -> AsyncThrowingStream<String, Error>
    /// Available local model IDs for /v1/models + /api/tags.
    typealias ModelListHandler = @Sendable () -> [String]

    private static let logger = Logger(subsystem: "com.epistemos.server", category: "LocalModelServer")
    private static let maxRequestBytes = 8 * 1024 * 1024 // 8 MB cap on a single request

    let port: UInt16
    private let generate: GenerateHandler
    private let stream: StreamHandler?
    private let listModels: ModelListHandler
    private let queue = DispatchQueue(label: "com.epistemos.localmodelserver", qos: .userInitiated)
    private var listener: NWListener?

    init(
        port: UInt16 = 1337,
        generate: @escaping GenerateHandler,
        stream: StreamHandler? = nil,
        listModels: @escaping ModelListHandler
    ) {
        self.port = port
        self.generate = generate
        self.stream = stream
        self.listModels = listModels
    }

    // MARK: - Lifecycle

    func start() throws {
        guard listener == nil else { return }
        let params = NWParameters.tcp
        // Loopback-only: refuse to ever bind a routable interface.
        params.requiredInterfaceType = .loopback
        params.allowLocalEndpointReuse = true
        guard let nwPort = NWEndpoint.Port(rawValue: port) else {
            throw ServerError.invalidPort(port)
        }
        let listener = try NWListener(using: params, on: nwPort)
        listener.newConnectionHandler = { [weak self] connection in
            self?.accept(connection)
        }
        let boundPort = port
        listener.stateUpdateHandler = { state in
            switch state {
            case .failed(let error):
                Self.logger.error("listener failed: \(error.localizedDescription, privacy: .public)")
            case .ready:
                Self.logger.info("LocalModelServer ready on 127.0.0.1:\(boundPort, privacy: .public)")
            default:
                break
            }
        }
        listener.start(queue: queue)
        self.listener = listener
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    // MARK: - Connection handling

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
                self.send(connection, status: 413, json: ["error": "request too large"])
                return
            }

            switch HTTPRequest.parse(buffer) {
            case .needMore:
                if isComplete {
                    connection.cancel()
                } else {
                    self.receive(connection, accumulated: buffer)
                }
            case .invalid:
                self.send(connection, status: 400, json: ["error": "bad request"])
            case .complete(let request):
                self.route(request, on: connection)
            }
        }
    }

    // MARK: - Routing

    private func route(_ request: HTTPRequest, on connection: NWConnection) {
        switch (request.method, request.path) {
        case ("GET", "/health"), ("GET", "/"):
            send(connection, status: 200, json: ["status": "ok", "service": "epistemos-local-model-server"])

        case ("GET", "/v1/models"):
            let models = listModels()
            let data = models.map { ["id": $0, "object": "model", "owned_by": "epistemos"] }
            send(connection, status: 200, json: ["object": "list", "data": data])

        case ("GET", "/api/tags"): // Ollama
            let models = listModels()
            let data = models.map { ["name": $0, "model": $0] }
            send(connection, status: 200, json: ["models": data])

        case ("POST", "/v1/chat/completions"), ("POST", "/chat/completions"):
            handleChatCompletions(request, on: connection)

        default:
            send(connection, status: 404, json: ["error": "not found: \(request.method) \(request.path)"])
        }
    }

    private func handleChatCompletions(_ request: HTTPRequest, on connection: NWConnection) {
        guard let body = try? JSONSerialization.jsonObject(with: request.body) as? [String: Any] else {
            send(connection, status: 400, json: ["error": "invalid JSON body"])
            return
        }
        let model = body["model"] as? String
        let wantsStream = (body["stream"] as? Bool) ?? false
        let maxTokens = (body["max_tokens"] as? Int) ?? 0
        let messages: [ChatMessage] = (body["messages"] as? [[String: Any]] ?? []).compactMap { raw in
            guard let role = raw["role"] as? String else { return nil }
            // content may be a string or OpenAI's array-of-parts; collapse to text.
            if let text = raw["content"] as? String {
                return ChatMessage(role: role, content: text)
            }
            if let parts = raw["content"] as? [[String: Any]] {
                let text = parts.compactMap { $0["text"] as? String }.joined()
                return ChatMessage(role: role, content: text)
            }
            return nil
        }
        guard !messages.isEmpty else {
            send(connection, status: 400, json: ["error": "no messages"])
            return
        }

        let id = "chatcmpl-\(UUID().uuidString.prefix(24))"
        let modelLabel = model ?? "epistemos-local"

        if wantsStream, let stream {
            sendSSEHeaders(connection)
            Task { [weak self] in
                guard let self else { return }
                do {
                    for try await delta in stream(messages, model, maxTokens) {
                        guard !delta.isEmpty else { continue }
                        let chunk: [String: Any] = [
                            "id": id, "object": "chat.completion.chunk", "model": modelLabel,
                            "choices": [["index": 0, "delta": ["content": delta], "finish_reason": NSNull()]],
                        ]
                        self.sendSSEData(connection, json: chunk)
                    }
                    let final: [String: Any] = [
                        "id": id, "object": "chat.completion.chunk", "model": modelLabel,
                        "choices": [["index": 0, "delta": [:], "finish_reason": "stop"]],
                    ]
                    self.sendSSEData(connection, json: final)
                    self.sendSSEDone(connection)
                } catch {
                    self.sendSSEData(connection, json: ["error": ["message": error.localizedDescription]])
                    self.sendSSEDone(connection)
                }
            }
        } else {
            Task { [weak self] in
                guard let self else { return }
                do {
                    let text = try await self.generate(messages, model, maxTokens)
                    let response: [String: Any] = [
                        "id": id, "object": "chat.completion", "model": modelLabel,
                        "choices": [[
                            "index": 0,
                            "message": ["role": "assistant", "content": text],
                            "finish_reason": "stop",
                        ]],
                    ]
                    self.send(connection, status: 200, json: response)
                } catch {
                    self.send(connection, status: 500, json: ["error": ["message": error.localizedDescription]])
                }
            }
        }
    }

    // MARK: - Response writers

    private func send(_ connection: NWConnection, status: Int, json: [String: Any]) {
        let body = (try? JSONSerialization.data(withJSONObject: json)) ?? Data("{}".utf8)
        var header = "HTTP/1.1 \(status) \(Self.reason(status))\r\n"
        header += "Content-Type: application/json\r\n"
        header += "Content-Length: \(body.count)\r\n"
        header += "Connection: close\r\n"
        header += "Access-Control-Allow-Origin: *\r\n\r\n"
        var data = Data(header.utf8)
        data.append(body)
        connection.send(content: data, completion: .contentProcessed { _ in connection.cancel() })
    }

    private func sendSSEHeaders(_ connection: NWConnection) {
        var header = "HTTP/1.1 200 OK\r\n"
        header += "Content-Type: text/event-stream\r\n"
        header += "Cache-Control: no-cache\r\n"
        header += "X-Accel-Buffering: no\r\n"
        header += "Connection: keep-alive\r\n"
        header += "Access-Control-Allow-Origin: *\r\n\r\n"
        connection.send(content: Data(header.utf8), completion: .contentProcessed { _ in })
    }

    private func sendSSEData(_ connection: NWConnection, json: [String: Any]) {
        let body = (try? JSONSerialization.data(withJSONObject: json)) ?? Data("{}".utf8)
        var line = Data("data: ".utf8)
        line.append(body)
        line.append(Data("\n\n".utf8))
        connection.send(content: line, completion: .contentProcessed { _ in })
    }

    private func sendSSEDone(_ connection: NWConnection) {
        connection.send(content: Data("data: [DONE]\n\n".utf8), completion: .contentProcessed { _ in connection.cancel() })
    }

    private static func reason(_ status: Int) -> String {
        switch status {
        case 200: return "OK"
        case 400: return "Bad Request"
        case 404: return "Not Found"
        case 413: return "Payload Too Large"
        case 500: return "Internal Server Error"
        default: return "Status"
        }
    }

    enum ServerError: Error { case invalidPort(UInt16) }

    /// Flatten an OpenAI message array into the (systemPrompt, prompt) shape the
    /// local inference client expects. System turns are concatenated into the
    /// system prompt; a lone user turn becomes the prompt verbatim, while a
    /// multi-turn conversation is rendered as a labeled transcript so the local
    /// model keeps context.
    static func flattenForLocalGenerate(_ messages: [ChatMessage]) -> (system: String?, prompt: String) {
        let system = messages
            .filter { $0.role == "system" }
            .map(\.content)
            .joined(separator: "\n\n")
        let conversation = messages.filter { $0.role != "system" }
        let prompt: String
        if conversation.count == 1, conversation[0].role == "user" {
            prompt = conversation[0].content
        } else {
            prompt = conversation.map { message in
                let label = message.role == "assistant" ? "Assistant" : "User"
                return "\(label): \(message.content)"
            }.joined(separator: "\n\n")
        }
        return (system.isEmpty ? nil : system, prompt)
    }
}

// MARK: - Minimal HTTP/1.1 request parser

// `nonisolated` so the pure parser is callable from the NWConnection receive
// queue (a nonisolated context). Without it, the module's default MainActor
// isolation would make `parse` main-actor-isolated and the call from `receive`
// would warn. All fields are `let` value types, so the struct is Sendable.
private nonisolated struct HTTPRequest {
    let method: String
    let path: String
    let headers: [String: String]
    let body: Data

    enum ParseResult {
        case needMore
        case invalid
        case complete(HTTPRequest)
    }

    /// Parse a buffer into a complete request, or report that more bytes are
    /// needed (headers not terminated yet, or body shorter than Content-Length).
    static func parse(_ buffer: Data) -> ParseResult {
        // Find header/body boundary (\r\n\r\n).
        let sep = Data("\r\n\r\n".utf8)
        guard let range = buffer.range(of: sep) else { return .needMore }
        let headerData = buffer.subdata(in: buffer.startIndex..<range.lowerBound)
        guard let headerText = String(data: headerData, encoding: .utf8) else { return .invalid }

        var lines = headerText.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else { return .invalid }
        lines.removeFirst()
        let requestParts = requestLine.split(separator: " ")
        guard requestParts.count >= 2 else { return .invalid }
        let method = String(requestParts[0])
        // Strip any query string for routing simplicity.
        let rawPath = String(requestParts[1])
        let path = rawPath.split(separator: "?", maxSplits: 1).first.map(String.init) ?? rawPath

        var headers: [String: String] = [:]
        for line in lines where !line.isEmpty {
            guard let colon = line.firstIndex(of: ":") else { continue }
            let key = line[line.startIndex..<colon].trimmingCharacters(in: .whitespaces).lowercased()
            let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            headers[key] = value
        }

        let contentLength = headers["content-length"].flatMap { Int($0) } ?? 0
        let bodyStart = range.upperBound
        let available = buffer.distance(from: bodyStart, to: buffer.endIndex)
        if available < contentLength { return .needMore }
        let body = contentLength > 0
            ? buffer.subdata(in: bodyStart..<buffer.index(bodyStart, offsetBy: contentLength))
            : Data()

        return .complete(HTTPRequest(method: method, path: path, headers: headers, body: body))
    }
}
