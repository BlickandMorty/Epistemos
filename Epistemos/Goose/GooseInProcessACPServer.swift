import CryptoKit
import Foundation
import Network
import os

protocol GooseMASAgentCoreRunning: AnyObject, Sendable {
    func streamGooseMASAgentCoreRun(
        sessionID: String,
        prompt: String,
        systemPrompt: String?,
        maxTokens: Int,
        providerName: String,
        vaultPath: String,
        permissionHandler: @escaping @Sendable (GooseMASAgentCorePermissionRequest) -> Bool
    ) -> AsyncThrowingStream<GooseMASAgentCoreRunEvent, Error>
}

nonisolated struct GooseMASAgentCorePermissionRequest: Sendable, Equatable {
    let id: String
    let toolName: String
    let inputJson: String
    let riskLevel: String
}

nonisolated enum GooseMASAgentCoreRunEvent: Sendable, Equatable {
    case textDelta(String)
    case thinkingDelta(String)
    case toolStarted(id: String, name: String, inputJson: String)
    case toolCompleted(id: String, name: String, result: String, isError: Bool)
    case permissionRequired(id: String, toolName: String, inputJson: String, riskLevel: String)
    case complete(stopReason: String, inputTokens: Int, outputTokens: Int)
    case error(String)
}

nonisolated final class GooseMASAgentCoreRunner: GooseMASAgentCoreRunning, @unchecked Sendable {
    private static let defaultVaultPath = NSHomeDirectory()
    private static let allowedMASTools = [
        "vault.search",
        "vault.read",
        "vault.write",
        "vault.list",
        "knowledge.recall",
        "web.search",
        "web.fetch",
        "http_fetch",
        "think",
    ]

    func streamGooseMASAgentCoreRun(
        sessionID: String,
        prompt: String,
        systemPrompt: String?,
        maxTokens: Int,
        providerName: String,
        vaultPath: String,
        permissionHandler: @escaping @Sendable (GooseMASAgentCorePermissionRequest) -> Bool
    ) -> AsyncThrowingStream<GooseMASAgentCoreRunEvent, Error> {
        AsyncThrowingStream { continuation in
            let delegate = GooseMASAgentCoreDelegate(
                emit: { event in
                    continuation.yield(event)
                },
                permissionHandler: permissionHandler
            )
            let normalizedVaultPath = vaultPath.trimmingCharacters(in: .whitespacesAndNewlines)
            let toolConfig = ToolConfig(
                vaultPath: normalizedVaultPath.isEmpty ? Self.defaultVaultPath : normalizedVaultPath,
                enableBash: false,
                enableWebSearch: true,
                toolTier: "agent",
                allowedToolNames: Self.allowedMASTools
            )
            let agentConfig = AgentConfigFFI(
                maxTurns: 24,
                maxOutputTokens: UInt32(max(1, min(maxTokens, 16_384))),
                contextThreshold: 120_000,
                enableThinking: true,
                effort: "high",
                systemPrompt: systemPrompt,
                autoApproveReads: false,
                autoApproveWrites: false,
                promptMode: "general",
                maxCostUsd: nil
            )
            let task = Task {
                do {
                    let result = try await runAgentSession(
                        sessionId: sessionID,
                        objective: prompt,
                        providerName: providerName,
                        toolConfig: toolConfig,
                        agentConfig: agentConfig,
                        delegate: delegate
                    )
                    delegate.finishIfNeeded(
                        stopReason: "end_turn",
                        inputTokens: Int(result.inputTokens),
                        outputTokens: Int(result.outputTokens)
                    )
                    continuation.finish()
                } catch {
                    delegate.emit(.error(EngineLogDiagnostics.logMessage(
                        for: error,
                        fallback: "agent_core MAS run failed"
                    )))
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
                cancelAgentSession(sessionId: sessionID)
            }
        }
    }
}

nonisolated private final class GooseMASAgentCoreDelegate: AgentStreamEventDelegate, @unchecked Sendable {
    private let emitEvent: @Sendable (GooseMASAgentCoreRunEvent) -> Void
    private let permissionHandler: @Sendable (GooseMASAgentCorePermissionRequest) -> Bool
    private let lock = NSLock()
    private var didComplete = false
    private var pendingPermissionRequests: [String: GooseMASAgentCorePermissionRequest] = [:]

    init(
        emit: @escaping @Sendable (GooseMASAgentCoreRunEvent) -> Void,
        permissionHandler: @escaping @Sendable (GooseMASAgentCorePermissionRequest) -> Bool
    ) {
        self.emitEvent = emit
        self.permissionHandler = permissionHandler
    }

    func emit(_ event: GooseMASAgentCoreRunEvent) {
        emitEvent(event)
    }

    func finishIfNeeded(stopReason: String, inputTokens: Int, outputTokens: Int) {
        lock.lock()
        let shouldFinish = !didComplete
        didComplete = true
        lock.unlock()
        guard shouldFinish else { return }
        emit(.complete(stopReason: stopReason, inputTokens: inputTokens, outputTokens: outputTokens))
    }

    func onThinkingDelta(thought: String) {
        emit(.thinkingDelta(thought))
    }

    func onTextDelta(delta: String) {
        emit(.textDelta(delta))
    }

    func onToolInputDelta(index: UInt32, partialJson: String) {
        _ = index
        _ = partialJson
    }

    func onToolStarted(toolUseId: String, name: String, inputJson: String) {
        emit(.toolStarted(id: toolUseId, name: name, inputJson: inputJson))
    }

    func onToolCompleted(toolUseId: String, result: String, isError: Bool) {
        emit(.toolCompleted(id: toolUseId, name: "", result: result, isError: isError))
    }

    func onSubagentSpawned(agentId: String, role: String) {
        emit(.toolStarted(id: agentId, name: "subagent.\(role)", inputJson: "{}"))
    }

    func onPermissionRequired(
        permissionId: String,
        toolName: String,
        inputJson: String,
        riskLevel: String
    ) {
        let request = GooseMASAgentCorePermissionRequest(
            id: permissionId,
            toolName: toolName,
            inputJson: inputJson,
            riskLevel: riskLevel
        )
        lock.lock()
        pendingPermissionRequests[permissionId] = request
        lock.unlock()
        emit(.permissionRequired(id: permissionId, toolName: toolName, inputJson: inputJson, riskLevel: riskLevel))
    }

    func onContextCompacting(currentTokens: UInt32) {
        emit(.thinkingDelta("Compacting context at \(currentTokens) tokens."))
    }

    func onContextCompacted(newMessageCount: UInt32) {
        emit(.thinkingDelta("Context compacted to \(newMessageCount) messages."))
    }

    func onTurnStarted(turnNumber: UInt32, messageCount: UInt32) {
        _ = turnNumber
        _ = messageCount
    }

    func onComplete(stopReason: String, inputTokens: UInt32, outputTokens: UInt32) {
        finishIfNeeded(
            stopReason: stopReason,
            inputTokens: Int(inputTokens),
            outputTokens: Int(outputTokens)
        )
    }

    func onError(message: String) {
        emit(.error(message))
    }

    func executeComputerAction(actionJson: String) -> String {
        _ = actionJson
        return #"{"success":false,"error":"Computer-use is Pro-only in the App Store Goose backend."}"#
    }

    func waitForPermission(permissionId: String) -> Bool {
        lock.lock()
        let request = pendingPermissionRequests.removeValue(forKey: permissionId)
        lock.unlock()
        guard let request else { return false }
        return permissionHandler(request)
    }

    func askUserQuestion(questionJson: String) -> String {
        _ = questionJson
        return #"{"response":"","choice_index":null}"#
    }

    func perceiveApp(appName: String, depth: String) -> String {
        _ = appName
        _ = depth
        return #"{"elements":[],"screenshot_path":null,"latency_ms":0,"error":"macOS app perception is Pro-only in the App Store Goose backend."}"#
    }

    func interactWithApp(actionJson: String) -> String {
        _ = actionJson
        return #"{"success":false,"element_found":false,"action_performed":false,"error":"macOS app control is Pro-only in the App Store Goose backend."}"#
    }

    func startScreenWatch(watchJson: String) -> String {
        _ = watchJson
        return #"{"triggered":false,"reason":"screen watch is Pro-only in the App Store Goose backend.","elapsed_ms":0}"#
    }

    func manageSsmState(actionJson: String) -> String {
        _ = actionJson
        return #"{"success":false,"state_size_mb":0,"layers":0,"dtype":"none","duration_ms":0,"states":[],"error":"SSM state is unavailable in the App Store Goose backend."}"#
    }

    func generateConstrained(prompt: String, grammarJson: String) -> String {
        _ = prompt
        _ = grammarJson
        return #"{"output":"","tokens_generated":0,"constraint_violations_masked":0,"error":"constrained local generation is unavailable in the App Store Goose backend."}"#
    }

    func generateImage(prompt: String, aspectRatio: String) -> String {
        _ = prompt
        _ = aspectRatio
        return #"{"error":"image generation is unavailable in the App Store Goose backend."}"#
    }

    func triggerNightbrainJob(jobType: String, priority: String) -> String {
        _ = jobType
        _ = priority
        return #"{"job_id":"","status":"unavailable","estimated_duration_s":0,"error":"NightBrain is unavailable in the App Store Goose backend."}"#
    }

    func getPartnerContext(noteId: String, cursorOffset: UInt32) -> String {
        _ = noteId
        _ = cursorOffset
        return #"{"matches":[],"complexity":0,"suggestions":[]}"#
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

    private struct AgentCoreRunnerBox: @unchecked Sendable {
        let runner: any GooseMASAgentCoreRunning
    }

    private final class PendingPermissionResponse: @unchecked Sendable {
        private let semaphore = DispatchSemaphore(value: 0)
        private let lock = NSLock()
        private var approved = false

        func resolve(approved: Bool) {
            lock.lock()
            self.approved = approved
            lock.unlock()
            semaphore.signal()
        }

        func wait(timeout: TimeInterval) -> Bool {
            let result = semaphore.wait(timeout: .now() + timeout)
            guard result != .timedOut else { return false }
            lock.lock()
            defer { lock.unlock() }
            return approved
        }
    }

    private static let logger = Logger(subsystem: "com.epistemos.goose", category: "GooseInProcessACPServer")
    private static let maxHTTPRequestBytes = 256 * 1024
    private static let maxWebSocketBufferBytes = 2 * 1024 * 1024
    private static let maxHTTPHostHeaderCharacters = 256
    private static let maxHTTPOriginHeaderCharacters = 512
    private static let defaultPromptMaxTokens = 4_096
    private static let permissionResponseTimeoutSeconds: TimeInterval = 300
    private static let thirdPartyAIConsentDefaultsKey =
        "Epistemos.Goose.MAS.ThirdPartyAIConsentProviderIDs.v1"

    private let secretKey: String
    private let catalog: GooseMASAgentCoreCatalog
    private let agentCoreRunner: AgentCoreRunnerBox
    private let queue = DispatchQueue(label: "com.epistemos.goose.inprocess-acp", qos: .userInitiated)
    private var configValues: [String: Any] = [:]
    private var providerConfigValues: [String: [String: String]] = [:]
    private var preferenceValues: [String: Any] = [:]
    private var defaultProviderID: String?
    private var defaultModelID: String?
    private let pendingPermissionsLock = NSLock()
    private var pendingPermissions: [String: PendingPermissionResponse] = [:]
    private let statusLock = NSLock()
    private var _status: Status = .idle
    private var listener: NWListener?
    private var boundPort: UInt16?
    private var sessions: [String: Session] = [:]

    var status: Status { statusLock.withLock { _status } }

    init(
        secretKey: String,
        catalog: GooseMASAgentCoreCatalog = .load(),
        agentCoreRunner: (any GooseMASAgentCoreRunning)? = nil
    ) {
        self.secretKey = secretKey
        self.catalog = catalog
        self.agentCoreRunner = AgentCoreRunnerBox(runner: agentCoreRunner ?? GooseMASAgentCoreRunner())
        let defaultProvider = catalog.providers.first { $0.configured } ?? catalog.providers.first
        self.defaultProviderID = defaultProvider?.providerId
        self.defaultModelID = defaultProvider?.defaultModel
        if let defaultProvider {
            configValues["GOOSE_PROVIDER"] = defaultProvider.providerId
            configValues["GOOSE_MODEL"] = defaultProvider.defaultModel
        }
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
                self.boundPort = port
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
        boundPort = nil
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
        guard authorizeHTTPRequestEnvelope(request, on: connection) else { return }
        let method = request.method.uppercased()
        switch (method, request.path) {
        case ("OPTIONS", _):
            sendHTTP(connection, GooseInProcessACPHTTPRequest.response(
                status: 204,
                body: "",
                accessControlAllowOrigin: Self.allowedCORSOrigin(for: request)
            ))
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
            sendHTTPJSON(connection, ["config": configValues], request: request)
        case ("POST", "/config/read"):
            guard authorizeREST(request, on: connection) else { return }
            let body = request.jsonBody()
            let key = body["key"] as? String ?? ""
            sendHTTPJSON(connection, configValues[key] ?? NSNull(), request: request)
        case ("POST", "/config/upsert"):
            guard authorizeREST(request, on: connection) else { return }
            let body = request.jsonBody()
            if let key = body["key"] as? String, !key.isEmpty {
                configValues[key] = body["value"] ?? NSNull()
            }
            sendHTTPJSON(connection, ["ok": true], request: request)
        case ("POST", "/config/remove"):
            guard authorizeREST(request, on: connection) else { return }
            let body = request.jsonBody()
            if let key = body["key"] as? String {
                configValues.removeValue(forKey: key)
            }
            sendHTTPJSON(connection, ["ok": true], request: request)
        case ("GET", "/config/providers"):
            guard authorizeREST(request, on: connection) else { return }
            sendHTTPJSON(connection, restProviderDetails(), request: request)
        case ("GET", "/config/provider-catalog"):
            guard authorizeREST(request, on: connection) else { return }
            sendHTTPJSON(connection, catalog.providerCatalogResult(), request: request)
        case ("GET", "/config/extensions"):
            guard authorizeREST(request, on: connection) else { return }
            sendHTTPJSON(connection, ["extensions": [], "_meta": catalog.metadata()], request: request)
        case ("GET", "/features"):
            guard authorizeREST(request, on: connection) else { return }
            sendHTTPJSON(connection, ["features": ["masBoundedGoose": true], "_meta": catalog.metadata()], request: request)
        default:
            sendHTTP(connection, GooseInProcessACPHTTPRequest.response(status: 404, body: "not found"))
        }
    }

    private func sendHTTP(_ connection: NWConnection, _ data: Data) {
        connection.send(content: data, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    private func sendHTTPJSON(
        _ connection: NWConnection,
        _ object: Any,
        status: Int = 200,
        request: GooseInProcessACPHTTPRequest? = nil
    ) {
        guard JSONSerialization.isValidJSONObject(object) || object is NSNull || object is String || object is Bool || object is NSNumber else {
            sendHTTP(connection, GooseInProcessACPHTTPRequest.jsonResponse(
                status: 500,
                object: ["error": "invalid json response"],
                accessControlAllowOrigin: request.flatMap(Self.allowedCORSOrigin)
            ))
            return
        }
        sendHTTP(connection, GooseInProcessACPHTTPRequest.jsonResponse(
            status: status,
            object: object,
            accessControlAllowOrigin: request.flatMap(Self.allowedCORSOrigin)
        ))
    }

    private func authorizeHTTPRequestEnvelope(_ request: GooseInProcessACPHTTPRequest, on connection: NWConnection) -> Bool {
        guard Self.isAllowedLoopbackHostHeader(request.header("host"), boundPort: boundPort) else {
            sendHTTP(connection, GooseInProcessACPHTTPRequest.response(status: 403, body: "forbidden host"))
            return false
        }
        guard Self.isAllowedOriginHeader(request.header("origin")) else {
            sendHTTP(connection, GooseInProcessACPHTTPRequest.response(status: 403, body: "forbidden origin"))
            return false
        }
        return true
    }

    private func authorizeREST(_ request: GooseInProcessACPHTTPRequest, on connection: NWConnection) -> Bool {
        guard request.header("x-secret-key") == secretKey else {
            sendHTTPJSON(connection, ["error": "unauthorized"], status: 401, request: request)
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
        if object["method"] == nil, completePendingPermissionResponse(from: object) {
            return []
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
        case "_goose/unstable/providers/config/read":
            return [Self.jsonResponse(id: id, result: providerConfigReadResult(params: params))]
        case "_goose/unstable/providers/config/save",
             "_goose/unstable/providers/config/authenticate":
            return [Self.jsonResponse(id: id, result: providerConfigSaveResult(params: params))]
        case "_goose/unstable/providers/config/delete":
            return [Self.jsonResponse(id: id, result: providerConfigDeleteResult(params: params))]
        case "_goose/unstable/providers/supported-models/list":
            return [Self.jsonResponse(id: id, result: supportedModelsResult(params: params))]
        case "_goose/unstable/providers/catalog/template":
            if let result = providerTemplateResult(params: params) {
                return [Self.jsonResponse(id: id, result: result)]
            }
            return [Self.jsonError(
                id: id,
                code: -32602,
                message: "Unknown provider catalog template.",
                data: catalog.metadata()
            )]
        case "_goose/unstable/preferences/read":
            return [Self.jsonResponse(id: id, result: preferencesReadResult(params: params))]
        case "_goose/unstable/preferences/save":
            savePreferences(params: params)
            return [Self.jsonResponse(id: id, result: [:])]
        case "_goose/unstable/preferences/remove":
            removePreferences(params: params)
            return [Self.jsonResponse(id: id, result: [:])]
        case "_goose/unstable/defaults/read":
            return [Self.jsonResponse(id: id, result: defaultsResult())]
        case "_goose/unstable/defaults/save":
            saveDefaults(params: params)
            return [Self.jsonResponse(id: id, result: defaultsResult())]
        case "_goose/unstable/epistemos/third-party-ai-consent/read":
            return [Self.jsonResponse(id: id, result: thirdPartyAIConsentReadResult())]
        case "_goose/unstable/epistemos/third-party-ai-consent/save":
            return [Self.jsonResponse(id: id, result: thirdPartyAIConsentSaveResult(params: params))]
        case "_goose/unstable/epistemos/third-party-ai-consent/revoke":
            return [Self.jsonResponse(id: id, result: thirdPartyAIConsentRevokeResult(params: params))]
        case "_goose/unstable/config/extensions/list",
             "_goose/unstable/extensions/list":
            return [Self.jsonResponse(id: id, result: catalog.extensionsResult())]
        case "_goose/unstable/sources/list",
             "_goose/unstable/recipes/list",
             "_goose/unstable/skills/list":
            return [Self.jsonResponse(id: id, result: emptySourcesResult())]
        case "_goose/unstable/schedules/list":
            return [Self.jsonResponse(id: id, result: emptySchedulesResult())]
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

    private func providerConfigReadResult(params: [String: Any]) -> [String: Any] {
        guard let provider = provider(for: params["providerId"] as? String) else {
            return ["fields": [], "_meta": catalog.metadata()]
        }
        let saved = providerConfigValues[provider.providerId] ?? [:]
        return [
            "fields": provider.configKeys.map { key in
                let value = saved[key.name]
                return [
                    "key": key.name,
                    "value": key.secret ? NSNull() : (value ?? NSNull()),
                    "isSet": value?.isEmpty == false,
                    "isSecret": key.secret,
                    "required": key.required,
                ] as [String: Any]
            },
            "_meta": catalog.metadata(),
        ]
    }

    private func providerConfigSaveResult(params: [String: Any]) -> [String: Any] {
        let providerID = (params["providerId"] as? String) ?? defaultProviderID ?? ""
        let fields = params["fields"] as? [[String: Any]] ?? []
        var values = providerConfigValues[providerID] ?? [:]
        for field in fields {
            guard let key = field["key"] as? String else { continue }
            values[key] = String(describing: field["value"] ?? "")
        }
        providerConfigValues[providerID] = values
        return providerConfigChangeResult(providerID: providerID, configured: true)
    }

    private func providerConfigDeleteResult(params: [String: Any]) -> [String: Any] {
        let providerID = (params["providerId"] as? String) ?? defaultProviderID ?? ""
        providerConfigValues.removeValue(forKey: providerID)
        return providerConfigChangeResult(providerID: providerID, configured: false)
    }

    private func providerConfigChangeResult(providerID: String, configured: Bool) -> [String: Any] {
        [
            "status": providerStatus(providerID: providerID, configuredOverride: configured),
            "refresh": [
                "providerId": providerID,
                "started": false,
                "reason": "MAS in-process backend keeps provider inventory in-process.",
                "_meta": catalog.metadata(),
            ],
        ]
    }

    private func providerStatus(providerID: String, configuredOverride: Bool? = nil) -> [String: Any] {
        let provider = provider(for: providerID)
        return [
            "providerId": providerID,
            "configured": configuredOverride ?? provider?.configured ?? (providerConfigValues[providerID]?.isEmpty == false),
            "isConfigured": configuredOverride ?? provider?.configured ?? (providerConfigValues[providerID]?.isEmpty == false),
            "stale": provider?.stale ?? false,
            "refreshing": provider?.refreshing ?? false,
        ]
    }

    private func supportedModelsResult(params: [String: Any]) -> [String: Any] {
        let providerID = (params["providerId"] as? String) ?? defaultProviderID ?? ""
        let models = provider(for: providerID)?.models.map(\.id) ?? []
        return [
            "providerId": providerID,
            "models": models,
            "_meta": catalog.metadata(),
        ]
    }

    private func providerTemplateResult(params: [String: Any]) -> [String: Any]? {
        guard let provider = provider(for: params["providerId"] as? String) else { return nil }
        return [
            "template": [
                "providerId": provider.providerId,
                "name": provider.providerName,
                "format": provider.providerType,
                "apiUrl": "",
                "models": provider.models.map { ["id": $0.id, "name": $0.name] },
                "supportsStreaming": true,
                "envVar": provider.configKeys.first(where: \.secret)?.name ?? "",
                "docUrl": "",
            ],
            "_meta": catalog.metadata(),
        ]
    }

    private func preferencesReadResult(params: [String: Any]) -> [String: Any] {
        let requested = params["keys"] as? [String] ?? []
        let keys = requested.isEmpty ? Array(preferenceValues.keys) : requested
        return [
            "values": keys.compactMap { key -> [String: Any]? in
                guard let value = preferenceValues[key] else { return nil }
                return ["key": key, "value": value]
            },
            "_meta": catalog.metadata(),
        ]
    }

    private func savePreferences(params: [String: Any]) {
        let values = params["values"] as? [[String: Any]] ?? []
        for entry in values {
            guard let key = entry["key"] as? String else { continue }
            preferenceValues[key] = entry["value"] ?? NSNull()
        }
    }

    private func removePreferences(params: [String: Any]) {
        let keys = params["keys"] as? [String] ?? []
        for key in keys {
            preferenceValues.removeValue(forKey: key)
        }
    }

    private func defaultsResult() -> [String: Any] {
        [
            "providerId": defaultProviderID ?? NSNull(),
            "modelId": defaultModelID ?? NSNull(),
            "_meta": catalog.metadata(),
        ]
    }

    private func saveDefaults(params: [String: Any]) {
        if let providerID = params["providerId"] as? String, !providerID.isEmpty {
            defaultProviderID = providerID
            configValues["GOOSE_PROVIDER"] = providerID
            if defaultModelID == nil {
                defaultModelID = provider(for: providerID)?.defaultModel
            }
        }
        if let modelID = params["modelId"] as? String, !modelID.isEmpty {
            defaultModelID = modelID
            configValues["GOOSE_MODEL"] = modelID
        }
    }

    private func provider(for providerID: String?) -> GooseMASAgentCoreCatalog.Provider? {
        guard let providerID, !providerID.isEmpty else {
            return defaultProviderID.flatMap { id in catalog.providers.first { $0.providerId == id } }
                ?? catalog.providers.first
        }
        return catalog.providers.first { $0.providerId == providerID }
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

    private func emptySchedulesResult() -> [String: Any] {
        [
            "jobs": [],
            "schedules": [],
            "items": [],
            "_meta": catalog.metadata(),
        ]
    }

    private func thirdPartyAIConsentReadResult() -> [String: Any] {
        let granted = thirdPartyAIConsentProviderIDs()
        return [
            "providers": catalog.providers.map { provider in
                [
                    "providerId": provider.providerId,
                    "providerName": provider.providerName,
                    "requiresConsent": Self.requiresThirdPartyAIConsent(provider),
                    "accepted": granted.contains(provider.providerId),
                ]
            },
            "selectedProviderId": selectedProviderIDForConsent() ?? NSNull(),
            "selectedProviderRequiresConsent": selectedProviderRequiresThirdPartyAIConsent(),
            "selectedProviderAccepted": selectedProviderHasThirdPartyAIConsent(),
            "remoteMcpEndpoints": [],
            "_meta": [
                "goose": [
                    "policyProfile": catalog.policyProfile,
                    "thirdPartyAIConsentRequired": true,
                    "appReviewGuideline": "5.1.2(i)",
                ],
            ],
        ]
    }

    private func thirdPartyAIConsentSaveResult(params: [String: Any]) -> [String: Any] {
        let providerIDs = Self.consentProviderIDs(from: params, fallback: selectedProviderIDForConsent())
        let accepted = params["accepted"] as? Bool ?? true
        var granted = thirdPartyAIConsentProviderIDs()
        if accepted {
            granted.formUnion(providerIDs)
        } else {
            granted.subtract(providerIDs)
        }
        saveThirdPartyAIConsentProviderIDs(granted)
        return thirdPartyAIConsentReadResult()
    }

    private func thirdPartyAIConsentRevokeResult(params: [String: Any]) -> [String: Any] {
        var granted = thirdPartyAIConsentProviderIDs()
        let providerIDs = Self.consentProviderIDs(from: params, fallback: selectedProviderIDForConsent())
        if providerIDs.isEmpty || params["all"] as? Bool == true {
            granted.removeAll()
        } else {
            granted.subtract(providerIDs)
        }
        saveThirdPartyAIConsentProviderIDs(granted)
        return thirdPartyAIConsentReadResult()
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
        let runnerBox = agentCoreRunner

        Task { [weak self, box, run, runnerBox] in
            guard let self else { return }
            var outputUTF8Bytes = 0
            do {
                guard self.ensureThirdPartyAIConsentForPrompt(run, on: box) else {
                    self.finishPromptRun(
                        run,
                        on: box,
                        errorMessage: "Third-party AI consent is required before MAS Goose can send this prompt."
                    )
                    return
                }
                let providerName = self.providerNameForAgentCore()
                let stream = runnerBox.runner.streamGooseMASAgentCoreRun(
                    sessionID: run.sessionID,
                    prompt: run.prompt,
                    systemPrompt: run.systemPrompt,
                    maxTokens: run.maxTokens,
                    providerName: providerName,
                    vaultPath: self.vaultPathForAgentCore(),
                    permissionHandler: { [weak self, box, run] request in
                        guard let self else { return false }
                        return self.requestAgentCorePermission(request, sessionID: run.sessionID, on: box)
                    }
                )
                for try await event in stream {
                    if Task.isCancelled {
                        self.finishPromptRun(run, on: box, stopReason: "cancelled", outputUTF8Bytes: outputUTF8Bytes)
                        return
                    }
                    switch event {
                    case .textDelta(let chunk):
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
                    case .thinkingDelta(let thought):
                        guard !thought.isEmpty else { continue }
                        self.sendJSONMessages([
                            Self.agentThoughtChunk(
                                sessionID: run.sessionID,
                                messageID: run.messageID,
                                created: run.created,
                                text: thought
                            ),
                        ], on: box)
                    case .toolStarted(let id, let name, let inputJson):
                        self.sendJSONMessages([
                            Self.toolCallNotification(
                                sessionID: run.sessionID,
                                toolCallID: id,
                                title: Self.toolTitle(name: name, inputJson: inputJson),
                                kind: Self.toolKind(for: name),
                                status: "in_progress"
                            ),
                        ], on: box)
                    case .toolCompleted(let id, let name, let result, let isError):
                        self.sendJSONMessages([
                            Self.toolCallUpdateNotification(
                                sessionID: run.sessionID,
                                toolCallID: id,
                                title: Self.toolResultTitle(name: name, result: result, isError: isError),
                                kind: Self.toolKind(for: name),
                                status: isError ? "failed" : "completed"
                            ),
                        ], on: box)
                    case .permissionRequired(let id, let toolName, let inputJson, let riskLevel):
                        self.sendJSONMessages([
                            Self.toolCallUpdateNotification(
                                sessionID: run.sessionID,
                                toolCallID: id,
                                title: Self.permissionTitle(toolName: toolName, inputJson: inputJson, riskLevel: riskLevel),
                                kind: Self.toolKind(for: toolName),
                                status: "pending"
                            ),
                        ], on: box)
                    case .complete(let stopReason, let inputTokens, let outputTokens):
                        self.finishPromptRun(
                            run,
                            on: box,
                            stopReason: stopReason,
                            inputTokens: inputTokens,
                            outputTokens: outputTokens
                        )
                        return
                    case .error(let message):
                        self.finishPromptRun(run, on: box, errorMessage: message)
                        return
                    }
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
        stopReason: String,
        inputTokens: Int,
        outputTokens: Int
    ) {
        sendJSONMessages([
            Self.clearActiveRunNotification(sessionID: run.sessionID),
            Self.usageNotification(
                sessionID: run.sessionID,
                inputTokens: inputTokens,
                outputTokens: outputTokens
            ),
            Self.jsonResponse(
                id: run.requestID,
                result: [
                    "stopReason": stopReason,
                    "usage": [
                        "inputTokens": inputTokens,
                        "outputTokens": outputTokens,
                        "totalTokens": inputTokens + outputTokens,
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

    private func providerNameForAgentCore() -> String {
        let providerID = defaultProviderID ?? providerConfigValues.keys.sorted().first ?? ""
        switch providerID {
        case "anthropic":
            return "claude_opus"
        case "openai":
            return "openai"
        case "google":
            return "gemini_pro"
        case "deepseek", "kimi", "zai", "minimax":
            return providerID
        default:
            return providerID.isEmpty ? "claude_opus" : providerID
        }
    }

    private func vaultPathForAgentCore() -> String {
        let candidates = [
            configValues["EPISTEMOS_VAULT_PATH"] as? String,
            configValues["VAULT_PATH"] as? String,
            sessions.values.first?.cwd,
            NSHomeDirectory(),
        ]
        return candidates
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty } ?? NSHomeDirectory()
    }

    private func ensureThirdPartyAIConsentForPrompt(_ run: PromptRun, on box: WebSocketConnectionBox) -> Bool {
        #if EPISTEMOS_APP_STORE
        guard selectedProviderRequiresThirdPartyAIConsent(),
              !selectedProviderHasThirdPartyAIConsent() else {
            return true
        }
        guard let providerID = selectedProviderIDForConsent() else { return false }
        let providerName = selectedProviderForConsent()?.providerName ?? providerID
        let approved = requestThirdPartyAIConsent(
            providerID: providerID,
            providerName: providerName,
            sessionID: run.sessionID,
            on: box
        )
        guard approved else { return false }
        var granted = thirdPartyAIConsentProviderIDs()
        granted.insert(providerID)
        saveThirdPartyAIConsentProviderIDs(granted)
        return true
        #else
        _ = run
        _ = box
        return true
        #endif
    }

    private func selectedProviderRequiresThirdPartyAIConsent() -> Bool {
        guard let provider = selectedProviderForConsent() else { return true }
        return Self.requiresThirdPartyAIConsent(provider)
    }

    private func selectedProviderHasThirdPartyAIConsent() -> Bool {
        guard let providerID = selectedProviderIDForConsent() else { return false }
        return thirdPartyAIConsentProviderIDs().contains(providerID)
    }

    private func selectedProviderIDForConsent() -> String? {
        selectedProviderForConsent()?.providerId
            ?? defaultProviderID
            ?? providerConfigValues.keys.sorted().first
    }

    private func selectedProviderForConsent() -> GooseMASAgentCoreCatalog.Provider? {
        let providerID = defaultProviderID ?? providerConfigValues.keys.sorted().first
        guard let providerID else { return catalog.providers.first }
        return catalog.providers.first { $0.providerId == providerID }
            ?? catalog.providers.first
    }

    private func thirdPartyAIConsentProviderIDs() -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: Self.thirdPartyAIConsentDefaultsKey) ?? [])
    }

    private func saveThirdPartyAIConsentProviderIDs(_ providerIDs: Set<String>) {
        let bounded = providerIDs
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .map { String($0.prefix(GooseACPProtocolBounds.maxInventoryIDCharacters)) }
            .sorted()
        UserDefaults.standard.set(bounded, forKey: Self.thirdPartyAIConsentDefaultsKey)
    }

    private func requestThirdPartyAIConsent(
        providerID: String,
        providerName: String,
        sessionID: String,
        on box: WebSocketConnectionBox
    ) -> Bool {
        let requestID = "mas_ai_consent_\(UUID().uuidString.lowercased())"
        let pending = PendingPermissionResponse()
        pendingPermissionsLock.lock()
        pendingPermissions[requestID] = pending
        pendingPermissionsLock.unlock()

        sendJSONMessages([
            Self.jsonRequest(
                id: requestID,
                method: "session/request_permission",
                params: [
                    "sessionId": sessionID,
                    "toolCall": [
                        "toolCallId": requestID,
                        "title": "Allow \(providerName) to process Goose prompts and selected vault context?",
                        "kind": "other",
                        "status": "pending",
                        "_meta": [
                            "goose": [
                                "providerId": providerID,
                                "providerName": providerName,
                                "appReviewGuideline": "5.1.2(i)",
                                "thirdPartyAIConsent": true,
                            ],
                        ],
                    ],
                    "options": [
                        [
                            "optionId": "allow_provider",
                            "name": "Allow \(providerName)",
                            "kind": "allow_once",
                        ],
                        [
                            "optionId": "reject_provider",
                            "name": "Deny",
                            "kind": "reject_once",
                        ],
                    ],
                ]
            ),
        ], on: box)

        let approved = pending.wait(timeout: Self.permissionResponseTimeoutSeconds)
        pendingPermissionsLock.lock()
        pendingPermissions.removeValue(forKey: requestID)
        pendingPermissionsLock.unlock()
        return approved
    }

    private func requestAgentCorePermission(
        _ request: GooseMASAgentCorePermissionRequest,
        sessionID: String,
        on box: WebSocketConnectionBox
    ) -> Bool {
        let requestID = "mas_perm_\(UUID().uuidString.lowercased())"
        let pending = PendingPermissionResponse()
        pendingPermissionsLock.lock()
        pendingPermissions[requestID] = pending
        pendingPermissionsLock.unlock()

        sendJSONMessages([
            Self.jsonRequest(
                id: requestID,
                method: "session/request_permission",
                params: [
                    "sessionId": sessionID,
                    "toolCall": [
                        "toolCallId": request.id,
                        "title": Self.permissionTitle(
                            toolName: request.toolName,
                            inputJson: request.inputJson,
                            riskLevel: request.riskLevel
                        ),
                        "kind": Self.toolKind(for: request.toolName),
                        "status": "pending",
                    ],
                    "options": [
                        [
                            "optionId": "allow_once",
                            "name": "Allow once",
                            "kind": "allow_once",
                        ],
                        [
                            "optionId": "reject_once",
                            "name": "Deny",
                            "kind": "reject_once",
                        ],
                    ],
                ]
            ),
        ], on: box)

        let approved = pending.wait(timeout: Self.permissionResponseTimeoutSeconds)
        pendingPermissionsLock.lock()
        pendingPermissions.removeValue(forKey: requestID)
        pendingPermissionsLock.unlock()
        return approved
    }

    private func completePendingPermissionResponse(from object: [String: Any]) -> Bool {
        guard object["result"] != nil || object["error"] != nil else { return false }
        guard let key = Self.requestIDKey(from: object["id"]) else { return true }

        pendingPermissionsLock.lock()
        let pending = pendingPermissions.removeValue(forKey: key)
        pendingPermissionsLock.unlock()

        guard let pending else { return true }
        pending.resolve(approved: Self.permissionResponseApproved(from: object))
        return true
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

    private static func agentThoughtChunk(
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
                    "sessionUpdate": "agent_thought_chunk",
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

    private static func toolCallNotification(
        sessionID: String,
        toolCallID: String,
        title: String,
        kind: String,
        status: String
    ) -> String {
        jsonNotification(
            method: "session/update",
            params: [
                "sessionId": sessionID,
                "update": [
                    "sessionUpdate": "tool_call",
                    "toolCallId": toolCallID,
                    "title": title,
                    "kind": kind,
                    "status": status,
                ],
            ]
        )
    }

    private static func toolCallUpdateNotification(
        sessionID: String,
        toolCallID: String,
        title: String,
        kind: String,
        status: String
    ) -> String {
        jsonNotification(
            method: "session/update",
            params: [
                "sessionId": sessionID,
                "update": [
                    "sessionUpdate": "tool_call_update",
                    "toolCallId": toolCallID,
                    "title": title,
                    "kind": kind,
                    "status": status,
                ],
            ]
        )
    }

    private static func toolTitle(name: String, inputJson: String) -> String {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = trimmedName.isEmpty ? "Tool" : trimmedName
        guard inputJson.utf8.count <= 180 else { return base }
        let compactInput = inputJson
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
        guard !compactInput.isEmpty, compactInput != "{}" else { return base }
        return "\(base) \(compactInput)"
    }

    private static func toolResultTitle(name: String, result: String, isError: Bool) -> String {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = trimmedName.isEmpty ? "Tool" : trimmedName
        let prefix = isError ? "\(base) failed" : "\(base) completed"
        let compactResult = result
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
        guard !compactResult.isEmpty else { return prefix }
        return "\(prefix): \(String(compactResult.prefix(180)))"
    }

    private static func permissionTitle(toolName: String, inputJson: String, riskLevel: String) -> String {
        let name = toolName.trimmingCharacters(in: .whitespacesAndNewlines)
        let risk = riskLevel.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = name.isEmpty ? "Tool permission" : "Permission: \(name)"
        let compactInput = inputJson
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
        let details = compactInput.isEmpty || compactInput == "{}" ? "" : " \(String(compactInput.prefix(120)))"
        return risk.isEmpty ? "\(base)\(details)" : "\(base) [\(risk)]\(details)"
    }

    private static func toolKind(for name: String) -> String {
        let lower = name.lowercased()
        if lower.contains("search") { return "search" }
        if lower.contains("read") || lower.contains("recall") || lower.contains("list") { return "read" }
        if lower.contains("write") || lower.contains("edit") || lower.contains("patch") { return "edit" }
        if lower.contains("delete") || lower.contains("remove") { return "delete" }
        if lower.contains("move") { return "move" }
        if lower.contains("fetch") || lower.contains("http") || lower.contains("web") { return "fetch" }
        if lower.contains("think") { return "think" }
        if lower.contains("shell") || lower.contains("terminal") || lower.contains("execute") { return "execute" }
        return "other"
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

    private static func requestIDKey(from id: Any?) -> String? {
        guard let id, !(id is NSNull) else { return nil }
        if let string = id as? String { return string }
        if let number = id as? NSNumber { return number.stringValue }
        return String(describing: id)
    }

    private static func permissionResponseApproved(from object: [String: Any]) -> Bool {
        guard object["error"] == nil,
              let result = object["result"] as? [String: Any] else {
            return false
        }
        guard let outcome = result["outcome"] as? [String: Any] else {
            return false
        }
        guard outcome["outcome"] as? String == "selected" else {
            return false
        }
        let optionID = (outcome["optionId"] as? String)
            ?? (outcome["option_id"] as? String)
            ?? ""
        let normalized = optionID.lowercased()
        return !normalized.contains("reject")
            && !normalized.contains("deny")
            && !normalized.contains("cancel")
    }

    private static func requiresThirdPartyAIConsent(_ provider: GooseMASAgentCoreCatalog.Provider) -> Bool {
        let haystack = [
            provider.providerId,
            provider.providerType,
            provider.category,
        ]
        .joined(separator: " ")
        .lowercased()
        for localToken in ["local", "mlx", "foundation", "apple", "ollama"] where haystack.contains(localToken) {
            return false
        }
        return true
    }

    private static func consentProviderIDs(from params: [String: Any], fallback: String?) -> Set<String> {
        var values: [String] = []
        if let providerID = params["providerId"] as? String {
            values.append(providerID)
        }
        if let providerIDs = params["providerIds"] as? [String] {
            values.append(contentsOf: providerIDs)
        }
        if values.isEmpty, let fallback {
            values.append(fallback)
        }
        return Set(values.compactMap { raw in
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty,
                  trimmed.count <= GooseACPProtocolBounds.maxInventoryIDCharacters,
                  !trimmed.utf8.contains(0) else {
                return nil
            }
            return trimmed
        })
    }

    private static func allowedCORSOrigin(for request: GooseInProcessACPHTTPRequest) -> String? {
        guard let origin = request.header("origin"),
              isAllowedOriginHeader(origin) else {
            return nil
        }
        return origin
    }

    private static func isAllowedOriginHeader(_ origin: String?) -> Bool {
        guard let origin else { return true }
        let trimmed = origin.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              trimmed.count <= maxHTTPOriginHeaderCharacters,
              !trimmed.utf8.contains(0) else {
            return false
        }
        if trimmed == "null" { return true }
        guard let components = URLComponents(string: trimmed),
              let scheme = components.scheme?.lowercased() else {
            return false
        }
        if scheme.hasPrefix("epistemos-goose-") {
            return true
        }
        guard scheme == "http" || scheme == "https" else { return false }
        return isAllowedLoopbackHost(components.host)
    }

    private static func isAllowedLoopbackHostHeader(_ hostHeader: String?, boundPort: UInt16?) -> Bool {
        guard let parsed = loopbackHostAndPort(from: hostHeader),
              isAllowedLoopbackHost(parsed.host) else {
            return false
        }
        if let boundPort {
            return parsed.port == boundPort
        }
        return true
    }

    private static func isAllowedLoopbackHost(_ host: String?) -> Bool {
        guard let host else { return false }
        let normalized = host.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalized == "127.0.0.1" || normalized == "localhost" || normalized == "::1"
    }

    private static func loopbackHostAndPort(from hostHeader: String?) -> (host: String, port: UInt16?)? {
        guard let hostHeader else { return nil }
        let trimmed = hostHeader.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              trimmed.count <= maxHTTPHostHeaderCharacters,
              !trimmed.utf8.contains(0) else {
            return nil
        }
        if trimmed.hasPrefix("[") {
            guard let end = trimmed.firstIndex(of: "]") else { return nil }
            let host = String(trimmed[trimmed.index(after: trimmed.startIndex)..<end])
            let suffix = trimmed[trimmed.index(after: end)...]
            guard suffix.isEmpty || suffix.hasPrefix(":") else { return nil }
            let port = suffix.dropFirst().isEmpty ? nil : UInt16(String(suffix.dropFirst()))
            return (host, port)
        }
        let parts = trimmed.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        let host = String(parts.first ?? "")
        let port = parts.count == 2 ? UInt16(String(parts[1])) : nil
        return host.isEmpty ? nil : (host, port)
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

    private static func jsonRequest(id: Any?, method: String, params: [String: Any]) -> String {
        serializeJSON([
            "jsonrpc": "2.0",
            "id": id ?? NSNull(),
            "method": method,
            "params": params,
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

    static func response(status: Int, body: String, accessControlAllowOrigin: String? = nil) -> Data {
        response(
            status: status,
            body: Data(body.utf8),
            contentType: "text/plain; charset=utf-8",
            accessControlAllowOrigin: accessControlAllowOrigin
        )
    }

    static func jsonResponse(status: Int, object: Any, accessControlAllowOrigin: String? = nil) -> Data {
        let data = (try? JSONSerialization.data(
            withJSONObject: object,
            options: [.fragmentsAllowed]
        )) ?? Data("null".utf8)
        return response(
            status: status,
            body: data,
            contentType: "application/json; charset=utf-8",
            accessControlAllowOrigin: accessControlAllowOrigin
        )
    }

    static func response(
        status: Int,
        body bodyData: Data,
        contentType: String,
        accessControlAllowOrigin: String? = nil
    ) -> Data {
        let reason: String
        switch status {
        case 204: reason = "No Content"
        case 200: reason = "OK"
        case 400: reason = "Bad Request"
        case 401: reason = "Unauthorized"
        case 403: reason = "Forbidden"
        case 404: reason = "Not Found"
        case 413: reason = "Payload Too Large"
        default: reason = "Error"
        }
        var response = Data()
        response.append(Data("HTTP/1.1 \(status) \(reason)\r\n".utf8))
        response.append(Data("Content-Type: \(contentType)\r\n".utf8))
        response.append(Data("Content-Length: \(bodyData.count)\r\n".utf8))
        if let accessControlAllowOrigin {
            response.append(Data("Access-Control-Allow-Origin: \(accessControlAllowOrigin)\r\n".utf8))
            response.append(Data("Access-Control-Allow-Headers: Content-Type, X-Secret-Key\r\n".utf8))
            response.append(Data("Access-Control-Allow-Methods: GET, POST, OPTIONS\r\n".utf8))
            response.append(Data("Vary: Origin\r\n".utf8))
        }
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
