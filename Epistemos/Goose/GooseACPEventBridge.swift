import Foundation
import Observation

@MainActor
@Observable
final class GooseACPEventBridge {
    enum Status: Equatable, Sendable {
        case idle
        case connecting
        case connected(agent: GooseACPImplementation?)
        case failed(String)
        case disconnected
    }

    private(set) var status: Status = .idle
    private(set) var pendingPermission: GooseACPPermissionPrompt?
    private(set) var pendingElicitation: GooseACPElicitationPrompt?
    private(set) var lastSessionUpdate: GooseACPSessionNotification?
    private(set) var unhandledDiagnostics: [GooseACPUnhandledDiagnostic] = []

    private var client: GooseACPClient?
    private var eventTask: Task<Void, Never>?
    private var connectionKey: String?
    private var injectedConnectionNumber = 0
    private var unhandledDiagnosticSequence = 0

    func connect(url: URL, clientVersion: String = Bundle.main.shortVersionString) {
        connect(
            key: url.absoluteString,
            transportFactory: { GooseACPURLSessionWebSocketTransport(url: url) },
            clientVersion: clientVersion,
            initialHandshakeAttempts: 6,
            retryDelayNanoseconds: 180_000_000,
            providerKeyBridge: GooseProviderKeyBridge()
        )
    }

    func connect(
        transport: any GooseACPTransport,
        clientVersion: String = Bundle.main.shortVersionString
    ) {
        injectedConnectionNumber += 1
        connect(
            key: "injected-\(injectedConnectionNumber)",
            transportFactory: { transport },
            clientVersion: clientVersion,
            initialHandshakeAttempts: 1,
            retryDelayNanoseconds: 0,
            providerKeyBridge: nil
        )
    }

    func connect(
        transportFactory: @escaping () -> any GooseACPTransport,
        clientVersion: String = Bundle.main.shortVersionString,
        initialHandshakeAttempts: Int,
        retryDelayNanoseconds: UInt64 = 0
    ) {
        injectedConnectionNumber += 1
        connect(
            key: "injected-\(injectedConnectionNumber)",
            transportFactory: transportFactory,
            clientVersion: clientVersion,
            initialHandshakeAttempts: initialHandshakeAttempts,
            retryDelayNanoseconds: retryDelayNanoseconds,
            providerKeyBridge: nil
        )
    }

    func disconnect() async {
        eventTask?.cancel()
        eventTask = nil
        if let client {
            await client.close()
        }
        client = nil
        pendingPermission = nil
        pendingElicitation = nil
        unhandledDiagnostics.removeAll()
        connectionKey = nil
        switch status {
        case .idle:
            break
        default:
            status = .disconnected
        }
    }

    func resolvePermission(promptID: String, optionID: String?) {
        guard let prompt = pendingPermission,
              prompt.id == promptID,
              let client else { return }
        pendingPermission = nil
        let response = optionID.map(GooseACPRequestPermissionResponse.selected(optionId:))
            ?? GooseACPRequestPermissionResponse.cancelled()
        Task { [weak self, client] in
            do {
                try await client.respondToPermission(requestId: prompt.requestID, response: response)
            } catch {
                self?.fail(error)
            }
        }
    }

    func acceptElicitation(promptID: String, values: [String: JSONValue]) {
        respondToElicitation(promptID: promptID, response: .accept(values))
    }

    func declineElicitation(promptID: String) {
        respondToElicitation(promptID: promptID, response: .decline())
    }

    func cancelElicitation(promptID: String) {
        respondToElicitation(promptID: promptID, response: .cancel())
    }

    private func connect(
        key: String,
        transportFactory: @escaping () -> any GooseACPTransport,
        clientVersion: String,
        initialHandshakeAttempts: Int,
        retryDelayNanoseconds: UInt64,
        providerKeyBridge: GooseProviderKeyBridge?
    ) {
        guard connectionKey != key else { return }
        eventTask?.cancel()
        client = nil
        pendingPermission = nil
        pendingElicitation = nil
        lastSessionUpdate = nil
        unhandledDiagnostics.removeAll()
        unhandledDiagnosticSequence = 0
        connectionKey = key
        status = .connecting

        eventTask = Task { [weak self] in
            await self?.runConnection(
                key: key,
                transportFactory: transportFactory,
                clientVersion: clientVersion,
                initialHandshakeAttempts: initialHandshakeAttempts,
                retryDelayNanoseconds: retryDelayNanoseconds,
                providerKeyBridge: providerKeyBridge
            )
        }
    }

    private func runConnection(
        key: String,
        transportFactory: () -> any GooseACPTransport,
        clientVersion: String,
        initialHandshakeAttempts: Int,
        retryDelayNanoseconds: UInt64,
        providerKeyBridge: GooseProviderKeyBridge?
    ) async {
        let attempts = max(1, initialHandshakeAttempts)
        for attempt in 1...attempts {
            guard connectionKey == key, !Task.isCancelled else { return }
            let client = GooseACPClient(transport: transportFactory(), clientVersion: clientVersion)
            self.client = client
            do {
                let response = try await client.initialize()
                guard connectionKey == key, !Task.isCancelled else {
                    await client.close()
                    return
                }
                markConnected(agent: response.agentInfo)
                if let providerKeyBridge {
                    _ = await providerKeyBridge.syncConfiguredProviderKeys(to: client)
                }
                while !Task.isCancelled {
                    handle(try await client.receiveEvent())
                }
                await client.close()
                return
            } catch {
                await client.close()
                guard !Task.isCancelled, connectionKey == key else { return }
                if attempt == attempts {
                    fail(error)
                    return
                }
                status = .connecting
                if retryDelayNanoseconds > 0 {
                    try? await Task.sleep(nanoseconds: retryDelayNanoseconds)
                }
            }
        }
    }

    private func respondToElicitation(
        promptID: String,
        response: GooseACPCreateElicitationResponse
    ) {
        guard let prompt = pendingElicitation,
              prompt.id == promptID,
              let client else { return }
        pendingElicitation = nil
        Task { [weak self, client] in
            do {
                try await client.respondToElicitation(requestId: prompt.requestID, response: response)
            } catch {
                self?.fail(error)
            }
        }
    }

    private func markConnected(agent: GooseACPImplementation?) {
        status = .connected(agent: agent)
    }

    private func handle(_ event: GooseACPClientEvent) {
        switch event {
        case .sessionUpdate(let notification):
            lastSessionUpdate = notification
        case .permissionRequest(let id, let request):
            pendingPermission = GooseACPPermissionPrompt(requestID: id, request: request)
        case .elicitationRequest(let id, let request):
            pendingElicitation = GooseACPElicitationPrompt(requestID: id, request: request)
        case .unhandledRequest(let id, let method, let params):
            appendUnhandledDiagnostic(kind: .request, method: method, params: params)
            guard let client else { return }
            Task { [weak self, client] in
                do {
                    try await client.respondUnsupportedRequest(requestId: id, method: method)
                } catch {
                    self?.fail(error)
                }
            }
        case .unhandledNotification(let method, let params):
            appendUnhandledDiagnostic(kind: .notification, method: method, params: params)
        }
    }

    private func appendUnhandledDiagnostic(
        kind: GooseACPUnhandledDiagnostic.Kind,
        method: GooseACPMethod,
        params: JSONValue
    ) {
        unhandledDiagnosticSequence += 1
        unhandledDiagnostics.append(GooseACPUnhandledDiagnostic(
            sequence: unhandledDiagnosticSequence,
            kind: kind,
            method: method.rawValue,
            params: params
        ))
        if unhandledDiagnostics.count > 12 {
            unhandledDiagnostics.removeFirst(unhandledDiagnostics.count - 12)
        }
    }

    private func fail(_ error: Error) {
        status = .failed(error.localizedDescription)
    }
}

struct GooseACPPermissionPrompt: Identifiable, Equatable, Sendable {
    let requestID: GooseACPRequestID
    let request: GooseACPRequestPermissionRequest

    var id: String { requestID.stableDescription }
}

struct GooseACPElicitationPrompt: Identifiable, Equatable, Sendable {
    let requestID: GooseACPRequestID
    let request: GooseACPCreateElicitationRequest

    var id: String { requestID.stableDescription }
    var message: String { request.message }
    var fields: [GooseACPElicitationFormField] {
        GooseACPElicitationFormField.fields(from: request.requestedSchema)
    }
}

struct GooseACPUnhandledDiagnostic: Identifiable, Equatable, Sendable {
    enum Kind: String, Equatable, Sendable {
        case request
        case notification
    }

    let id: String
    let kind: Kind
    let method: String
    let parameterSummary: String

    init(sequence: Int, kind: Kind, method: String, params: JSONValue) {
        id = "\(kind.rawValue):\(sequence)"
        self.kind = kind
        self.method = method
        parameterSummary = Self.summarize(params)
    }

    private static func summarize(_ params: JSONValue) -> String {
        switch params {
        case .object(let object):
            let keys = object.keys.sorted()
            guard !keys.isEmpty else { return "object(empty)" }
            let visibleKeys = keys.prefix(6).joined(separator: ",")
            return keys.count > 6 ? "object(\(visibleKeys),...)" : "object(\(visibleKeys))"
        case .array(let values):
            return "array(\(values.count))"
        case .string:
            return "string"
        case .int, .double:
            return "number"
        case .bool:
            return "bool"
        case .null:
            return "null"
        }
    }
}

struct GooseACPElicitationFormField: Identifiable, Equatable, Sendable {
    enum FieldType: String, Equatable, Sendable {
        case string
        case number
        case boolean
        case unknown
    }

    let id: String
    let title: String
    let type: FieldType
    let isRequired: Bool

    static func fields(from schema: JSONValue) -> [Self] {
        guard case .object(let root) = schema,
              case .object(let properties)? = root["properties"] else {
            return []
        }
        let required = Set(root["required"]?.stringArrayValue ?? [])
        return properties.keys.sorted().map { key in
            let property = properties[key]?.objectValue ?? [:]
            return Self(
                id: key,
                title: property["title"]?.stringValue ?? key,
                type: FieldType(rawValue: property["type"]?.stringValue ?? "") ?? .unknown,
                isRequired: required.contains(key)
            )
        }
    }
}

private extension GooseACPRequestID {
    var stableDescription: String {
        switch self {
        case .int(let int):
            "int:\(int)"
        case .string(let string):
            "string:\(string)"
        }
    }
}

private extension Bundle {
    var shortVersionString: String {
        object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }
}

private extension JSONValue {
    var objectValue: [String: JSONValue]? {
        guard case .object(let object) = self else { return nil }
        return object
    }

    var stringValue: String? {
        guard case .string(let string) = self else { return nil }
        return string
    }

    var stringArrayValue: [String]? {
        guard case .array(let values) = self else { return nil }
        return values.compactMap(\.stringValue)
    }
}
