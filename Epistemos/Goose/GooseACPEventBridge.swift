import Foundation
import Observation

/// Errors surfaced by the live read/mutate passthrough used by native Goose routes.
nonisolated enum GooseACPBridgeError: Error, Equatable, Sendable {
    /// The bridge has no live ACP client (not connected yet, or torn down). Native routes show an
    /// honest blocked/empty state rather than inventing data.
    case notConnected
}

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
    /// Monotonic counter bumped each time the Epistemos→Goose provider-key sync (+ default-provider
    /// activation) completes for a fresh connection. The WebView host observes this to RELOAD the
    /// SPA once credentials are actually mirrored into Goose — otherwise the SPA can read Goose's
    /// provider/credential state before the sync lands and cache a "Failed to load provider
    /// credentials" / empty-providers result that never self-heals (review H3).
    private(set) var providersSyncedGeneration = 0

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
                self?.recordResponseSendFailure(error, context: "permission")
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

    // MARK: - Live read/mutate passthrough (native-route data source — Step 3 per-route migration)

    /// The native SwiftUI routes (the Models picker first) read/write through the SAME live ACP
    /// connection the WebView uses — never a second spawn, never a Swift-hardcoded roster (GOLDEN
    /// RULE: every provider/model comes from live enumeration). These forward to the live
    /// `GooseACPClient`; they THROW `notConnected` when the bridge has no live client so the view
    /// renders an honest empty/error state instead of a silent fallback.
    /// The Models-picker provider source: available providers (built-in + configured) each with
    /// their models inline. One call, no per-provider live enumeration that could hang.
    func liveProviderInventory(timeout: Duration? = nil) async throws -> [GooseACPProviderInventoryEntry] {
        guard let client else { throw GooseACPBridgeError.notConnected }
        return try await client.listGooseProviderInventory(timeout: timeout)
    }

    func liveProviderCatalog(format: String? = nil) async throws -> GooseACPProviderCatalogListResponse {
        guard let client else { throw GooseACPBridgeError.notConnected }
        return try await client.listGooseProviderCatalog(format: format)
    }

    func liveProviderSupportedModels(
        providerId: String
    ) async throws -> GooseACPProviderSupportedModelsListResponse {
        guard let client else { throw GooseACPBridgeError.notConnected }
        return try await client.listGooseProviderSupportedModels(providerId: providerId)
    }

    func liveDefaults(timeout: Duration? = nil) async throws -> GooseACPDefaultsReadResponse {
        guard let client else { throw GooseACPBridgeError.notConnected }
        return try await client.readGooseDefaults(timeout: timeout)
    }

    @discardableResult
    func saveLiveDefaults(
        providerId: String,
        modelId: String?,
        timeout: Duration? = nil
    ) async throws -> GooseACPDefaultsReadResponse {
        guard let client else { throw GooseACPBridgeError.notConnected }
        return try await client.saveGooseDefaults(providerId: providerId, modelId: modelId, timeout: timeout)
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
        // ACP-correctness (deep-hardening 2026-06-29 #3): closing the OUTGOING client is required —
        // cancelling eventTask does not interrupt a suspended receiveEvent/response continuation,
        // and the old client's read loop + WebSocket leak otherwise (incoming frames pile into an
        // unread queue forever on an idle-but-open superseded connection). Mirror disconnect().
        let previousClient = client
        eventTask?.cancel()
        client = nil
        if let previousClient {
            Task { await previousClient.close() }
        }
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
        // `attempts` bounds CONSECUTIVE failed handshakes. A successful connect
        // resets the counter (below) so transient mid-session socket drops over a
        // long-lived connection each earn a fresh reconnect budget instead of
        // sharing one exhaustible pool with the initial handshake. A genuinely
        // dead endpoint still terminates: every reconnect fails, the counter
        // climbs to `attempts`, and we clear the key + fail.
        let attempts = max(1, initialHandshakeAttempts)
        var attempt = 0
        while true {
            attempt += 1
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
                attempt = 0
                if let providerKeyBridge {
                    await syncProviderKeys(via: providerKeyBridge, client: client, key: key)
                    await activateDefaultProviderIfNeeded(client: client)
                    // H3: tell the host the credentials are now mirrored so it can reload the SPA
                    // (which may have already cached an empty/failed provider state from before sync).
                    guard connectionKey == key, !Task.isCancelled else { await client.close(); return }
                    providersSyncedGeneration += 1
                }
                while !Task.isCancelled {
                    handle(try await client.receiveEvent())
                }
                await client.close()
                return
            } catch {
                await client.close()
                guard !Task.isCancelled, connectionKey == key else { return }
                if attempt >= attempts {
                    // Clear the key so a later connect(key:) to the SAME url can
                    // re-establish without forcing a full disconnect()/runtime
                    // restart. Scoped to the terminal path (not shared fail()) so
                    // transient permission/elicitation send errors don't reset it.
                    connectionKey = nil
                    // review B-L1: drop the now-closed client so live routes report a clean
                    // .notConnected instead of re-throwing the terminal transport error (the
                    // .failed-status-with-non-nil-client state was inconsistent).
                    self.client = nil
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
                self?.recordResponseSendFailure(error, context: "elicitation")
            }
        }
    }

    private func markConnected(agent: GooseACPImplementation?) {
        status = .connected(agent: agent)
    }

    // M3: the FIRST `listGooseProviders` right after `initialize` can fail while Goose's provider
    // subsystem is still warming up — which previously left EVERY key skipped as
    // `providerInventoryUnavailable` (result discarded), so the user's Keychain credentials were
    // never mirrored for the whole session and Auth showed "Failed to load provider credentials".
    // Retry a few times with a short backoff when the inventory wasn't reachable; stop as soon as
    // any sync actually applies/skips on real data (or the connection is superseded/cancelled).
    private func syncProviderKeys(
        via providerKeyBridge: GooseProviderKeyBridge,
        client: GooseACPClient,
        key: String
    ) async {
        for attempt in 0..<4 {
            guard connectionKey == key, !Task.isCancelled else { return }
            let result = await providerKeyBridge.syncConfiguredProviderKeys(to: client)
            let inventoryUnavailable = result.applied.isEmpty
                && result.skipped.contains { $0.reason == .providerInventoryUnavailable }
            if !inventoryUnavailable { return }
            if attempt < 3 {
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
        }
    }

    // Best-effort: when no default provider is set yet, auto-activate the SINGLE
    // configured provider so a returning user lands ready-to-chat instead of on
    // Goose's setup screen. Guarded to exactly-one-configured (never guesses among
    // several) and fully non-fatal — any failure leaves the live connection intact
    // and Goose's own onboarding in charge. Every value comes live from Goose ACP.
    private func activateDefaultProviderIfNeeded(client: GooseACPClient) async {
        do {
            let defaults = try await client.readGooseDefaults()
            if let providerId = defaults.providerId,
               !providerId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return
            }
            let statusResponse = try await client.readGooseProviderConfigStatus(providerIds: [])
            let configured = statusResponse.statuses.filter(\.isConfigured).map(\.providerId)
            guard configured.count == 1, let providerId = configured.first else {
                return
            }
            let modelId = try? await defaultModelID(for: providerId, client: client)
            _ = try await client.saveGooseDefaults(providerId: providerId, modelId: modelId)
        } catch {
            // Non-fatal: never break the live connection over a default-activation miss.
        }
    }

    private func defaultModelID(for providerId: String, client: GooseACPClient) async throws -> String? {
        let response = try await client.listGooseProviders(providerIDs: [providerId])
        for entry in response.entries {
            guard let object = entry.objectValue,
                  (object["providerId"]?.stringValue ?? object["provider_id"]?.stringValue) == providerId else {
                continue
            }
            if let model = object["defaultModel"]?.stringValue ?? object["default_model"]?.stringValue,
               !model.isEmpty {
                return model
            }
        }
        return nil
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
                    // B-M1: a request for a method we DO support (permission/elicitation) reaches here
                    // ONLY because its params failed typed decode → answer -32602 (invalid params),
                    // NOT -32601 (method-not-found). Telling goose "request_permission not found" could
                    // make it conclude the client can't prompt and silently auto-proceed/auto-reject
                    // tool calls; -32602 says "supported method, this payload was invalid" so the
                    // permission gate stays intact. Genuinely unknown methods still get -32601.
                    switch method {
                    case .requestPermission, .createElicitation:
                        try await client.respondInvalidParams(requestId: id, method: method)
                    default:
                        try await client.respondUnsupportedRequest(requestId: id, method: method)
                    }
                } catch {
                    self?.recordResponseSendFailure(error, context: "unhandled-request")
                }
            }
        case .unhandledNotification(let method, let params):
            appendUnhandledDiagnostic(kind: .notification, method: method, params: params)
        case .serverError(let code, let message, let data):
            // #4: contained server-level error (null-id JSON-RPC error). Recorded as a diagnostic;
            // the connection stays alive (terminal fail() is reserved for transport errors).
            recordDiagnostic(kind: .notification, method: "server/error(\(code))", params: data ?? .string(message))
        }
    }

    private func appendUnhandledDiagnostic(
        kind: GooseACPUnhandledDiagnostic.Kind,
        method: GooseACPMethod,
        params: JSONValue
    ) {
        recordDiagnostic(kind: kind, method: method.rawValue, params: params)
    }

    private func recordDiagnostic(
        kind: GooseACPUnhandledDiagnostic.Kind,
        method: String,
        params: JSONValue
    ) {
        unhandledDiagnosticSequence += 1
        unhandledDiagnostics.append(GooseACPUnhandledDiagnostic(
            sequence: unhandledDiagnosticSequence,
            kind: kind,
            method: method,
            params: params
        ))
        if unhandledDiagnostics.count > 12 {
            unhandledDiagnostics.removeFirst(unhandledDiagnostics.count - 12)
        }
    }

    private func fail(_ error: Error) {
        status = .failed(error.localizedDescription)
    }

    // M1 (WebView-host review): a transient error sending a RESPONSE (permission/elicitation/
    // unsupported-request reply) must NOT flip the bridge to .failed. The socket and read loop are
    // still alive (incoming events keep flowing), and the terminal `fail()` path is the only place
    // that clears `connectionKey` — so a `.connected → .failed` here is a FALSE-RED the UI can't
    // recover from in place (a re-connect to the same key is a no-op while the key is still set).
    // Record it as a diagnostic and leave the live status intact; genuine connection death still
    // surfaces through the read loop's terminal `fail()`.
    private func recordResponseSendFailure(_ error: Error, context: String) {
        recordDiagnostic(
            kind: .request,
            method: "response-send-failed(\(context))",
            params: .string(error.localizedDescription)
        )
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
