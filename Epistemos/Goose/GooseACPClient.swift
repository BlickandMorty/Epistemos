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
}

actor GooseACPClient {
    private let transport: any GooseACPTransport
    private let clientVersion: String
    private let encoder = JSONEncoder()
    private var nextRequestNumber = 1
    private var queuedEvents: [GooseACPClientEvent] = []
    private var queuedResponses: [GooseACPRequestID: Result<JSONValue, Error>] = [:]
    private var waitingEvents: [CheckedContinuation<GooseACPClientEvent, Error>] = []
    private var waitingResponses: [GooseACPRequestID: CheckedContinuation<JSONValue, Error>] = [:]
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

    func newSession(cwd: String) async throws -> GooseACPNewSessionResponse {
        try await sendRequest(
            method: .newSession,
            params: GooseACPNewSessionRequest(cwd: cwd),
            response: GooseACPNewSessionResponse.self
        )
    }

    func prompt(sessionId: String, text: String) async throws -> GooseACPPromptResponse {
        try await sendRequest(
            method: .prompt,
            params: GooseACPPromptRequest(sessionId: sessionId, prompt: [.text(text)]),
            response: GooseACPPromptResponse.self
        )
    }

    func listGooseProviders(providerIDs: [String] = []) async throws -> GooseACPProvidersListResponse {
        try await sendCustomRequest(
            method: .providersList,
            params: GooseACPProvidersListRequest(providerIds: providerIDs),
            response: GooseACPProvidersListResponse.self
        )
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

    func readGooseDefaults() async throws -> GooseACPDefaultsReadResponse {
        try await sendCustomRequest(
            method: .defaultsRead,
            params: GooseACPDefaultsReadRequest(),
            response: GooseACPDefaultsReadResponse.self
        )
    }

    func saveGooseDefaults(providerId: String, modelId: String? = nil) async throws -> GooseACPDefaultsReadResponse {
        try await sendCustomRequest(
            method: .defaultsSave,
            params: GooseACPDefaultsSaveRequest(providerId: providerId, modelId: modelId),
            response: GooseACPDefaultsReadResponse.self
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
        await transport.close()
        readLoopTask?.cancel()
        readLoopTask = nil
        fail(GooseACPProtocolError.closed)
    }

    private func ensureReadLoop() {
        guard readLoopTask == nil, terminalError == nil else { return }
        let transport = transport
        readLoopTask = Task { [weak self, transport] in
            let decoder = JSONDecoder()
            while !Task.isCancelled {
                do {
                    guard let text = try await transport.receive(),
                          let data = text.data(using: .utf8) else {
                        throw GooseACPProtocolError.unsupportedMessage
                    }
                    let message = try decoder.decode(GooseACPIncomingMessage.self, from: data)
                    guard let self else { return }
                    try await self.ingest(message)
                } catch {
                    if !Task.isCancelled {
                        await self?.fail(error)
                    }
                    return
                }
            }
        }
    }

    private func sendRequest<Params: Encodable, Response: Decodable>(
        method: GooseACPMethod,
        params: Params,
        response: Response.Type
    ) async throws -> Response {
        try await sendRequest(method: method.rawValue, params: params, response: response)
    }

    private func sendCustomRequest<Params: Encodable, Response: Decodable>(
        method: GooseACPCustomMethod,
        params: Params,
        response: Response.Type
    ) async throws -> Response {
        try await sendRequest(method: method.rawValue, params: params, response: response)
    }

    private func sendRequest<Params: Encodable, Response: Decodable>(
        method: String,
        params: Params,
        response: Response.Type
    ) async throws -> Response {
        ensureReadLoop()
        let id = nextRequestID()
        let request = GooseACPJSONRPCRequest(id: id, method: method, params: params)
        try await send(request)
        let result = try await waitForResponse(id)
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

    private func waitForResponse(_ id: GooseACPRequestID) async throws -> JSONValue {
        if let result = queuedResponses.removeValue(forKey: id) {
            return try result.get()
        }

        if let terminalError {
            throw terminalError
        }

        return try await withCheckedThrowingContinuation { continuation in
            waitingResponses[id] = continuation
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
            fail(GooseACPProtocolError.jsonRPCError(
                code: error.code,
                message: error.message,
                data: error.data
            ))
        case let message:
            deliverEvent(try event(from: message))
        }
    }

    private func deliverResponse(_ response: Result<JSONValue, Error>, id: GooseACPRequestID) {
        if let waiter = waitingResponses.removeValue(forKey: id) {
            switch response {
            case .success(let result):
                waiter.resume(returning: result)
            case .failure(let error):
                waiter.resume(throwing: error)
            }
        } else {
            queuedResponses[id] = response
        }
    }

    private func deliverEvent(_ event: GooseACPClientEvent?) {
        guard let event else { return }
        if waitingEvents.isEmpty {
            queuedEvents.append(event)
        } else {
            waitingEvents.removeFirst().resume(returning: event)
        }
    }

    private func fail(_ error: Error) {
        terminalError = error
        queuedResponses.removeAll()

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

    private func event(from message: GooseACPIncomingMessage) throws -> GooseACPClientEvent? {
        switch message {
        case .notification(.sessionUpdate, let params):
            return .sessionUpdate(try params.decoded(GooseACPSessionNotification.self))
        case .notification(let method, let params):
            return .unhandledNotification(method: method, params: params)
        case .request(let id, .requestPermission, let params):
            return .permissionRequest(
                id: id,
                try params.decoded(GooseACPRequestPermissionRequest.self)
            )
        case .request(let id, .createElicitation, let params):
            return .elicitationRequest(
                id: id,
                try params.decoded(GooseACPCreateElicitationRequest.self)
            )
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
