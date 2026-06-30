import Foundation

nonisolated protocol GooseACPTransport: Sendable {
    func send(_ text: String) async throws
    func receive() async throws -> String?
    func close() async
}

actor GooseACPURLSessionWebSocketTransport: GooseACPTransport {
    private let task: URLSessionWebSocketTask

    init(url: URL, session: URLSession = .shared) {
        task = session.webSocketTask(with: url)
        task.resume()
    }

    func send(_ text: String) async throws {
        try await task.send(.string(text))
    }

    func receive() async throws -> String? {
        switch try await task.receive() {
        case .string(let text):
            text
        case .data(let data):
            String(data: data, encoding: .utf8)
        @unknown default:
            nil
        }
    }

    func close() async {
        task.cancel(with: .goingAway, reason: nil)
    }
}

nonisolated enum GooseACPClientEvent: Equatable, Sendable {
    case sessionUpdate(GooseACPSessionNotification)
    case permissionRequest(id: GooseACPRequestID, GooseACPRequestPermissionRequest)
    case elicitationRequest(id: GooseACPRequestID, GooseACPCreateElicitationRequest)
    case unhandledRequest(id: GooseACPRequestID, method: GooseACPMethod, params: JSONValue)
    case unhandledNotification(method: GooseACPMethod, params: JSONValue)
    /// A JSON-RPC error frame with null/absent id (parse-error / invalid-request / global server
    /// notice). Application-level, NOT a transport failure — contained as a diagnostic so it does
    /// not tear down the connection. Deep-hardening 2026-06-29 #4.
    case serverError(code: Int, message: String, data: JSONValue?)
}

actor GooseACPClient {
    nonisolated static let maxQueuedEvents = 1_024
    nonisolated static let maxQueuedResponses = 256

    private let transport: any GooseACPTransport
    private let clientVersion: String
    private let encoder = JSONEncoder()
    private var nextRequestNumber = 1
    private var queuedEvents: [GooseACPClientEvent] = []
    private var queuedResponses: [GooseACPRequestID: Result<JSONValue, Error>] = [:]
    private var queuedResponseOrder: [GooseACPRequestID] = []
    private var waitingEvents: [CheckedContinuation<GooseACPClientEvent, Error>] = []
    private var waitingResponses: [GooseACPRequestID: CheckedContinuation<JSONValue, Error>] = [:]
    private var waitingResponseTimeouts: [GooseACPRequestID: Task<Void, Never>] = [:]
    private var abandonedResponseIDs: Set<GooseACPRequestID> = []
    private var terminalError: Error?
    private var readLoopTask: Task<Void, Never>?

    init(transport: any GooseACPTransport, clientVersion: String) {
        self.transport = transport
        self.clientVersion = clientVersion
    }

    deinit {
        readLoopTask?.cancel()
    }

    func initialize() async throws -> GooseACPInitializeResponse {
        try await sendRequest(
            method: .initialize,
            params: GooseACPInitializeRequest.epistemos(clientVersion: clientVersion),
            response: GooseACPInitializeResponse.self
        )
    }

    func newSession(
        cwd: String,
        metadata: [String: JSONValue]? = nil
    ) async throws -> GooseACPNewSessionResponse {
        try await sendRequest(
            method: .newSession,
            params: GooseACPNewSessionRequest(cwd: cwd, metadata: metadata),
            response: GooseACPNewSessionResponse.self
        )
    }

    func listSessions(
        cursor: String? = nil,
        cwd: String? = nil,
        additionalDirectories: [String]? = nil,
        metadata: [String: JSONValue]? = nil
    ) async throws -> GooseACPListSessionsResponse {
        try await sendRequest(
            method: .listSessions,
            params: GooseACPListSessionsRequest(
                cursor: cursor,
                cwd: cwd,
                additionalDirectories: additionalDirectories,
                metadata: metadata
            ),
            response: GooseACPListSessionsResponse.self
        )
    }

    func loadSession(
        sessionId: String,
        cwd: String,
        mcpServers: [JSONValue] = [],
        additionalDirectories: [String]? = nil,
        metadata: [String: JSONValue]? = nil
    ) async throws -> GooseACPLoadSessionResponse {
        try await sendRequest(
            method: .loadSession,
            params: GooseACPLoadSessionRequest(
                sessionId: sessionId,
                cwd: cwd,
                mcpServers: mcpServers,
                additionalDirectories: additionalDirectories,
                metadata: metadata
            ),
            response: GooseACPLoadSessionResponse.self
        )
    }

    func forkSession(
        sessionId: String,
        cwd: String,
        additionalDirectories: [String]? = nil,
        conversationBefore: Int? = nil,
        metadata: [String: JSONValue]? = nil
    ) async throws -> GooseACPForkSessionResponse {
        try await sendRequest(
            method: .forkSession,
            params: GooseACPForkSessionRequest(
                sessionId: sessionId,
                cwd: cwd,
                additionalDirectories: additionalDirectories,
                conversationBefore: conversationBefore,
                metadata: metadata
            ),
            response: GooseACPForkSessionResponse.self
        )
    }

    func prompt(sessionId: String, text: String) async throws -> GooseACPPromptResponse {
        try await sendRequest(
            method: .prompt,
            params: GooseACPPromptRequest(sessionId: sessionId, prompt: [.text(text)]),
            response: GooseACPPromptResponse.self
        )
    }

    func sendGooseCustomRequest(method: String, params: JSONValue = .object([:])) async throws -> JSONValue {
        try await sendRequest(method: method, params: params, response: JSONValue.self)
    }

    func listGooseProviders(
        providerIDs: [String] = [],
        timeout: Duration? = nil
    ) async throws -> GooseACPProvidersListResponse {
        try await sendCustomRequest(
            method: .providersList,
            params: GooseACPProvidersListRequest(providerIds: providerIDs),
            response: GooseACPProvidersListResponse.self,
            timeout: timeout
        )
    }

    /// Typed `providers/list` inventory: the available providers (built-in + configured custom) each
    /// with their models inline. This is the Models-picker source — one call, no per-provider live
    /// enumeration that could hang, and it includes the built-in providers the template catalog omits.
    func listGooseProviderInventory(timeout: Duration? = nil) async throws -> [GooseACPProviderInventoryEntry] {
        let response = try await listGooseProviders(timeout: timeout)
        // Tolerant per-entry decode: an entry that fails to decode (e.g. a future Goose drops the
        // required providerId) is unusable in a picker anyway — skip it so ONE malformed entry can
        // never blank the entire list. This matches the WebView oracle, which degrades per-entry
        // rather than failing wholesale. The transport call above still throws on a hard failure.
        return response.entries.compactMap { try? $0.decoded(GooseACPProviderInventoryEntry.self) }
    }

    func listGooseProviderSupportedModels(
        providerId: String
    ) async throws -> GooseACPProviderSupportedModelsListResponse {
        try await sendCustomRequest(
            method: .providerSupportedModelsList,
            params: GooseACPProviderSupportedModelsListRequest(providerId: providerId),
            response: GooseACPProviderSupportedModelsListResponse.self
        )
    }

    func listGooseProviderCatalog(format: String? = nil) async throws -> GooseACPProviderCatalogListResponse {
        try await sendCustomRequest(
            method: .providerCatalogList,
            params: GooseACPProviderCatalogListRequest(format: format),
            response: GooseACPProviderCatalogListResponse.self
        )
    }

    func readGooseProviderCatalogTemplate(providerId: String) async throws -> GooseACPProviderCatalogTemplateResponse {
        try await sendCustomRequest(
            method: .providerCatalogTemplate,
            params: GooseACPProviderCatalogTemplateRequest(providerId: providerId),
            response: GooseACPProviderCatalogTemplateResponse.self
        )
    }

    func listGooseProviderSetupCatalog() async throws -> GooseACPProviderSetupCatalogListResponse {
        try await sendCustomRequest(
            method: .providerSetupCatalogList,
            params: GooseACPProviderSetupCatalogListRequest(),
            response: GooseACPProviderSetupCatalogListResponse.self
        )
    }

    func readGooseProviderConfig(providerId: String) async throws -> GooseACPProviderConfigReadResponse {
        try await sendCustomRequest(
            method: .providerConfigRead,
            params: GooseACPProviderConfigReadRequest(providerId: providerId),
            response: GooseACPProviderConfigReadResponse.self
        )
    }

    func readGooseProviderConfigStatus(
        providerIds: [String] = []
    ) async throws -> GooseACPProviderConfigStatusResponse {
        try await sendCustomRequest(
            method: .providerConfigStatus,
            params: GooseACPProviderConfigStatusRequest(providerIds: providerIds),
            response: GooseACPProviderConfigStatusResponse.self
        )
    }

    func saveGooseProviderConfig(
        providerId: String,
        fields: [GooseACPProviderConfigFieldUpdate]
    ) async throws -> GooseACPProviderConfigChangeResponse {
        try await sendCustomRequest(
            method: .providerConfigSave,
            params: GooseACPProviderConfigSaveRequest(providerId: providerId, fields: fields),
            response: GooseACPProviderConfigChangeResponse.self
        )
    }

    func deleteGooseProviderConfig(providerId: String) async throws -> GooseACPProviderConfigChangeResponse {
        try await sendCustomRequest(
            method: .providerConfigDelete,
            params: GooseACPProviderConfigDeleteRequest(providerId: providerId),
            response: GooseACPProviderConfigChangeResponse.self
        )
    }

    func authenticateGooseProviderConfig(providerId: String) async throws -> GooseACPProviderConfigChangeResponse {
        try await sendCustomRequest(
            method: .providerConfigAuthenticate,
            params: GooseACPProviderConfigAuthenticateRequest(providerId: providerId),
            response: GooseACPProviderConfigChangeResponse.self
        )
    }

    func listGooseConfigExtensions() async throws -> GooseACPConfigExtensionsListResponse {
        try await sendCustomRequest(
            method: .configExtensionsList,
            params: GooseACPConfigExtensionsListRequest(),
            response: GooseACPConfigExtensionsListResponse.self
        )
    }

    func readGoosePreferences(
        keys: [GooseACPPreferenceKey] = []
    ) async throws -> GooseACPPreferencesReadResponse {
        try await sendCustomRequest(
            method: .preferencesRead,
            params: GooseACPPreferencesReadRequest(keys: keys),
            response: GooseACPPreferencesReadResponse.self
        )
    }

    func saveGoosePreferences(
        values: [GooseACPPreferenceValue]
    ) async throws -> GooseACPEmptyResponse {
        try await sendCustomRequest(
            method: .preferencesSave,
            params: GooseACPPreferencesSaveRequest(values: values),
            response: GooseACPEmptyResponse.self
        )
    }

    func removeGoosePreferences(
        keys: [GooseACPPreferenceKey]
    ) async throws -> GooseACPEmptyResponse {
        try await sendCustomRequest(
            method: .preferencesRemove,
            params: GooseACPPreferencesRemoveRequest(keys: keys),
            response: GooseACPEmptyResponse.self
        )
    }

    func readGooseDefaults(timeout: Duration? = nil) async throws -> GooseACPDefaultsReadResponse {
        try await sendCustomRequest(
            method: .defaultsRead,
            params: GooseACPDefaultsReadRequest(),
            response: GooseACPDefaultsReadResponse.self,
            timeout: timeout
        )
    }

    func saveGooseDefaults(
        providerId: String,
        modelId: String? = nil,
        timeout: Duration? = nil
    ) async throws -> GooseACPDefaultsReadResponse {
        try await sendCustomRequest(
            method: .defaultsSave,
            params: GooseACPDefaultsSaveRequest(providerId: providerId, modelId: modelId),
            response: GooseACPDefaultsReadResponse.self,
            timeout: timeout
        )
    }

    func listGooseSources(
        type: GooseACPSourceType? = nil,
        projectDir: String? = nil,
        includeProjectSources: Bool? = nil
    ) async throws -> GooseACPSourcesListResponse {
        try await sendCustomRequest(
            method: .sourcesList,
            params: GooseACPSourcesListRequest(
                type: type,
                projectDir: projectDir,
                includeProjectSources: includeProjectSources
            ),
            response: GooseACPSourcesListResponse.self
        )
    }

    func createGooseSource(
        type: GooseACPSourceType,
        name: String,
        description: String,
        content: String,
        target: GooseACPSourceScope,
        properties: [String: JSONValue]? = nil
    ) async throws -> GooseACPSourceResponse {
        try await sendCustomRequest(
            method: .sourcesCreate,
            params: GooseACPSourceCreateRequest(
                type: type,
                name: name,
                description: description,
                content: content,
                target: target,
                properties: properties
            ),
            response: GooseACPSourceResponse.self
        )
    }

    func updateGooseSource(
        type: GooseACPSourceType,
        path: String,
        name: String,
        description: String,
        content: String,
        properties: [String: JSONValue]? = nil
    ) async throws -> GooseACPSourceResponse {
        try await sendCustomRequest(
            method: .sourcesUpdate,
            params: GooseACPSourceUpdateRequest(
                type: type,
                path: path,
                name: name,
                description: description,
                content: content,
                properties: properties
            ),
            response: GooseACPSourceResponse.self
        )
    }

    func deleteGooseSource(type: GooseACPSourceType, path: String) async throws {
        _ = try await sendCustomRequest(
            method: .sourcesDelete,
            params: GooseACPSourceDeleteRequest(type: type, path: path),
            response: GooseACPEmptyResponse.self
        )
    }

    func exportGooseSource(type: GooseACPSourceType, path: String) async throws -> GooseACPSourceExportResponse {
        try await sendCustomRequest(
            method: .sourcesExport,
            params: GooseACPSourceExportRequest(type: type, path: path),
            response: GooseACPSourceExportResponse.self
        )
    }

    func importGooseSources(
        data: String,
        target: GooseACPSourceScope
    ) async throws -> GooseACPSourcesImportResponse {
        try await sendCustomRequest(
            method: .sourcesImport,
            params: GooseACPSourcesImportRequest(data: data, target: target),
            response: GooseACPSourcesImportResponse.self
        )
    }

    func readGooseSessionInfo(sessionId: String) async throws -> GooseACPSessionInfoResponse {
        try await sendCustomRequest(
            method: .sessionInfo,
            params: GooseACPSessionInfoRequest(sessionId: sessionId),
            response: GooseACPSessionInfoResponse.self
        )
    }

    func readGooseDiagnostics(
        sessionId: String,
        level: GooseACPDiagnosticsLevel
    ) async throws -> GooseACPDiagnosticsGetResponse {
        try await sendCustomRequest(
            method: .diagnosticsGet,
            params: GooseACPDiagnosticsGetRequest(sessionId: sessionId, level: level),
            response: GooseACPDiagnosticsGetResponse.self
        )
    }

    func respondToPermission(
        requestId: GooseACPRequestID,
        response: GooseACPRequestPermissionResponse
    ) async throws {
        try await sendResult(id: requestId, result: response)
    }

    func respondToElicitation(
        requestId: GooseACPRequestID,
        response: GooseACPCreateElicitationResponse
    ) async throws {
        try await sendResult(id: requestId, result: response)
    }

    func respondUnsupportedRequest(requestId: GooseACPRequestID, method: GooseACPMethod) async throws {
        try await sendError(id: requestId, error: .unsupportedRequest(method))
    }

    func respondInvalidParams(requestId: GooseACPRequestID, method: GooseACPMethod) async throws {
        try await sendError(id: requestId, error: .invalidParams(method))
    }

    func receiveEvent() async throws -> GooseACPClientEvent {
        ensureReadLoop()

        if !queuedEvents.isEmpty {
            return queuedEvents.removeFirst()
        }

        if let terminalError {
            throw terminalError
        }

        return try await withCheckedThrowingContinuation { continuation in
            waitingEvents.append(continuation)
        }
    }

    func drainQueuedEvents() -> [GooseACPClientEvent] {
        ensureReadLoop()
        defer { queuedEvents.removeAll() }
        return queuedEvents
    }

    func close() async {
        readLoopTask?.cancel()
        readLoopTask = nil
        await transport.close()
        fail(GooseACPProtocolError.closed)
    }

    private func ensureReadLoop() {
        guard readLoopTask == nil, terminalError == nil else { return }
        let transport = transport
        readLoopTask = Task { [weak self, transport] in
            let decoder = JSONDecoder()
            while !Task.isCancelled {
                // Transport receive: a THROW here is a real connection failure (URLSessionWebSocketTask
                // throws on close/error) → terminal `fail()`. A returned nil is a non-text/binary
                // frame, NOT EOF, so it is a skippable bad frame (see B-HIGH-1 below).
                let received: String?
                do {
                    received = try await transport.receive()
                } catch {
                    if !Task.isCancelled {
                        await self?.fail(error)
                    }
                    return
                }
                guard !Task.isCancelled else { return }
                guard let self else { return }
                // Per-frame containment (B-HIGH-1): a single undecodable frame — a non-text frame, a
                // malformed-JSON frame, or one whose envelope doesn't match — must NOT tear down the
                // whole connection or discard the real responses queued behind it. Record a structured
                // diagnostic and skip just that frame. Terminal `fail()` stays reserved for transport
                // failures (above). `continue` re-suspends on `transport.receive()` (no busy-loop,
                // since a closed socket throws rather than returning nil).
                guard let received, let data = received.data(using: .utf8) else {
                    await self.recordSkippedFrame("non-text ACP frame")
                    continue
                }
                let message: GooseACPIncomingMessage
                do {
                    message = try decoder.decode(GooseACPIncomingMessage.self, from: data)
                } catch {
                    await self.recordSkippedFrame("undecodable ACP frame: \(error.localizedDescription)")
                    continue
                }
                do {
                    try await self.ingest(message)
                } catch {
                    // `ingest` only throws from `event(from:)`'s typed decode, which already degrades
                    // to `.unhandled*` internally — an unexpected throw is contained, not terminal.
                    await self.recordSkippedFrame("ACP ingest error: \(error.localizedDescription)")
                    continue
                }
            }
        }
    }

    private func recordSkippedFrame(_ reason: String) {
        // B-HIGH-1: surface a skipped, undecodable frame as a contained diagnostic event (the bridge
        // records `.serverError` as an application diagnostic without tearing down the connection).
        // -32700 = JSON parse error; the frame carries no usable id, so there is nothing to answer.
        deliverEvent(.serverError(code: -32700, message: "Skipped undecodable ACP frame: \(reason)", data: nil))
    }

    private func sendRequest<Params: Encodable, Response: Decodable>(
        method: GooseACPMethod,
        params: Params,
        response: Response.Type,
        timeout: Duration? = nil
    ) async throws -> Response {
        try await sendRequest(method: method.rawValue, params: params, response: response, timeout: timeout)
    }

    private func sendCustomRequest<Params: Encodable, Response: Decodable>(
        method: GooseACPCustomMethod,
        params: Params,
        response: Response.Type,
        timeout: Duration? = nil
    ) async throws -> Response {
        try await sendRequest(method: method.rawValue, params: params, response: response, timeout: timeout)
    }

    private func sendRequest<Params: Encodable, Response: Decodable>(
        method: String,
        params: Params,
        response: Response.Type,
        timeout: Duration? = nil
    ) async throws -> Response {
        ensureReadLoop()
        let id = nextRequestID()
        let request = GooseACPJSONRPCRequest(id: id, method: method, params: params)
        try await send(request)
        let result = try await waitForResponse(id, method: method, timeout: timeout)
        return try result.decoded(Response.self)
    }

    private func sendResult<Result: Encodable>(id: GooseACPRequestID, result: Result) async throws {
        try await send(GooseACPJSONRPCResult(id: id, result: result))
    }

    private func sendError(id: GooseACPRequestID, error: GooseACPJSONRPCError) async throws {
        try await send(GooseACPJSONRPCErrorResult(id: id, error: error))
    }

    private func send<T: Encodable>(_ value: T) async throws {
        let data = try encoder.encode(value)
        guard let text = String(data: data, encoding: .utf8) else {
            throw GooseACPProtocolError.unsupportedMessage
        }
        try await transport.send(text)
    }

    private func waitForResponse(
        _ id: GooseACPRequestID,
        method: String,
        timeout: Duration?
    ) async throws -> JSONValue {
        if let result = removeQueuedResponse(for: id) {
            return try result.get()
        }

        if let terminalError {
            throw terminalError
        }

        return try await withCheckedThrowingContinuation { continuation in
            waitingResponses[id] = continuation
            guard let timeout else { return }
            waitingResponseTimeouts[id] = Task { [weak self] in
                do {
                    try await Task.sleep(for: timeout)
                } catch {
                    return
                }
                await self?.timeOutResponse(id: id, method: method, timeout: timeout)
            }
        }
    }

    private func ingest(_ message: GooseACPIncomingMessage) throws {
        switch message {
        case .response(let id, let result):
            deliverResponse(.success(result), id: id)
        case .error(let id?, let error):
            deliverResponse(
                .failure(GooseACPProtocolError.jsonRPCError(
                    code: error.code,
                    message: error.message,
                    data: error.data
                )),
                id: id
            )
        case .error(nil, let error):
            // #4: a null-id JSON-RPC error is application-level, not a transport failure. Contain
            // it as a diagnostic event; terminal fail() stays reserved for transport/frame-parse.
            deliverEvent(.serverError(code: error.code, message: error.message, data: error.data))
        case let message:
            deliverEvent(try event(from: message))
        }
    }

    private func deliverResponse(_ response: Result<JSONValue, Error>, id: GooseACPRequestID) {
        if let waiter = waitingResponses.removeValue(forKey: id) {
            waitingResponseTimeouts.removeValue(forKey: id)?.cancel()
            switch response {
            case .success(let result):
                waiter.resume(returning: result)
            case .failure(let error):
                waiter.resume(throwing: error)
            }
        } else if abandonedResponseIDs.remove(id) != nil {
            return
        } else {
            queueResponse(response, id: id)
        }
    }

    private func deliverEvent(_ event: GooseACPClientEvent?) {
        guard let event else { return }
        if waitingEvents.isEmpty {
            queuedEvents.append(event)
            trimQueuedEvents()
        } else {
            waitingEvents.removeFirst().resume(returning: event)
        }
    }

    private func removeQueuedResponse(for id: GooseACPRequestID) -> Result<JSONValue, Error>? {
        guard let response = queuedResponses.removeValue(forKey: id) else { return nil }
        queuedResponseOrder.removeAll { $0 == id }
        return response
    }

    private func queueResponse(_ response: Result<JSONValue, Error>, id: GooseACPRequestID) {
        if queuedResponses[id] == nil {
            queuedResponseOrder.append(id)
        }
        queuedResponses[id] = response
        trimQueuedResponses()
    }

    private func trimQueuedEvents() {
        let overflow = queuedEvents.count - Self.maxQueuedEvents
        guard overflow > 0 else { return }
        queuedEvents.removeFirst(overflow)
    }

    private func trimQueuedResponses() {
        let overflow = queuedResponseOrder.count - Self.maxQueuedResponses
        guard overflow > 0 else { return }
        let staleIDs = Array(queuedResponseOrder.prefix(overflow))
        queuedResponseOrder.removeFirst(overflow)
        for id in staleIDs {
            queuedResponses.removeValue(forKey: id)
        }
    }

    private func fail(_ error: Error) {
        terminalError = error
        queuedResponses.removeAll()
        queuedResponseOrder.removeAll()
        abandonedResponseIDs.removeAll()
        let timeoutTasks = Array(waitingResponseTimeouts.values)
        waitingResponseTimeouts.removeAll()
        for task in timeoutTasks {
            task.cancel()
        }

        let eventContinuations = waitingEvents
        waitingEvents.removeAll()
        for continuation in eventContinuations {
            continuation.resume(throwing: error)
        }

        let responseContinuations = Array(waitingResponses.values)
        waitingResponses.removeAll()
        for continuation in responseContinuations {
            continuation.resume(throwing: error)
        }
    }

    private func timeOutResponse(id: GooseACPRequestID, method: String, timeout: Duration) {
        waitingResponseTimeouts.removeValue(forKey: id)?.cancel()
        guard let waiter = waitingResponses.removeValue(forKey: id) else { return }
        abandonedResponseIDs.insert(id)
        waiter.resume(throwing: GooseACPProtocolError.responseTimedOut(method: method, id: id, timeout: timeout))
    }

    private func event(from message: GooseACPIncomingMessage) throws -> GooseACPClientEvent? {
        // Per-frame decode containment: a KNOWN method whose payload has drifted
        // (a missing/renamed required field on a future goose serve) must NOT tear
        // down the whole ACP connection. On a typed-decode miss we route to the
        // unhandled path so the event bridge records a structured diagnostic and (for
        // requests) still answers the server with a JSON-RPC error instead of leaving
        // it hanging — and the bridge answers a KNOWN-but-undecodable method with
        // -32602 (invalid params) vs an UNKNOWN method with -32601 (method-not-found),
        // so a permission/elicitation schema drift never reads as "client can't prompt"
        // (review B-M1). Terminal `fail()` stays reserved for transport-level errors
        // and the outer frame parse in `ensureReadLoop`.
        switch message {
        case .notification(.sessionUpdate, let params):
            if let notification = try? params.decoded(GooseACPSessionNotification.self) {
                return .sessionUpdate(notification)
            }
            return .unhandledNotification(method: .sessionUpdate, params: params)
        case .notification(let method, let params):
            return .unhandledNotification(method: method, params: params)
        case .request(let id, .requestPermission, let params):
            if let permission = try? params.decoded(GooseACPRequestPermissionRequest.self) {
                return .permissionRequest(id: id, permission)
            }
            return .unhandledRequest(id: id, method: .requestPermission, params: params)
        case .request(let id, .createElicitation, let params):
            if let elicitation = try? params.decoded(GooseACPCreateElicitationRequest.self) {
                return .elicitationRequest(id: id, elicitation)
            }
            return .unhandledRequest(id: id, method: .createElicitation, params: params)
        case .request(let id, let method, let params):
            return .unhandledRequest(id: id, method: method, params: params)
        case .response, .error:
            return nil
        }
    }

    private func nextRequestID() -> GooseACPRequestID {
        defer { nextRequestNumber += 1 }
        return .int(nextRequestNumber)
    }
}
