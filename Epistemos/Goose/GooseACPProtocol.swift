import Foundation

nonisolated enum GooseACPProtocolError: Error, Equatable, Sendable {
    case missingField(String)
    case unsupportedMessage
    case jsonRPCError(code: Int, message: String, data: JSONValue?)
    case closed
}

nonisolated enum GooseACPRequestID: Codable, Hashable, Sendable {
    case int(Int)
    case string(String)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let int = try? container.decode(Int.self) {
            self = .int(int)
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else {
            throw DecodingError.typeMismatch(
                GooseACPRequestID.self,
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "id must be int or string")
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .int(let int):
            try container.encode(int)
        case .string(let string):
            try container.encode(string)
        }
    }
}

nonisolated enum GooseACPMethod: Hashable, Sendable {
    case initialize
    case newSession
    case listSessions
    case loadSession
    case forkSession
    case prompt
    case sessionUpdate
    case requestPermission
    case createElicitation
    case unknown(String)

    init(rawValue: String) {
        switch rawValue {
        case "initialize":
            self = .initialize
        case "session/new":
            self = .newSession
        case "session/list":
            self = .listSessions
        case "session/load":
            self = .loadSession
        case "session/fork":
            self = .forkSession
        case "session/prompt":
            self = .prompt
        case "session/update":
            self = .sessionUpdate
        case "session/request_permission":
            self = .requestPermission
        case "elicitation/create":
            self = .createElicitation
        default:
            self = .unknown(rawValue)
        }
    }

    var rawValue: String {
        switch self {
        case .initialize:
            "initialize"
        case .newSession:
            "session/new"
        case .listSessions:
            "session/list"
        case .loadSession:
            "session/load"
        case .forkSession:
            "session/fork"
        case .prompt:
            "session/prompt"
        case .sessionUpdate:
            "session/update"
        case .requestPermission:
            "session/request_permission"
        case .createElicitation:
            "elicitation/create"
        case .unknown(let raw):
            raw
        }
    }
}

nonisolated struct GooseACPJSONRPCRequest<Params: Encodable>: Encodable {
    let id: GooseACPRequestID
    let method: String
    let params: Params

    private enum CodingKeys: String, CodingKey {
        case jsonrpc
        case id
        case method
        case params
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode("2.0", forKey: .jsonrpc)
        try container.encode(id, forKey: .id)
        try container.encode(method, forKey: .method)
        try container.encode(params, forKey: .params)
    }
}

nonisolated struct GooseACPJSONRPCResult<Result: Encodable>: Encodable {
    let id: GooseACPRequestID
    let result: Result

    private enum CodingKeys: String, CodingKey {
        case jsonrpc
        case id
        case result
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode("2.0", forKey: .jsonrpc)
        try container.encode(id, forKey: .id)
        try container.encode(result, forKey: .result)
    }
}

nonisolated struct GooseACPJSONRPCErrorResult: Encodable {
    let id: GooseACPRequestID
    let error: GooseACPJSONRPCError

    private enum CodingKeys: String, CodingKey {
        case jsonrpc
        case id
        case error
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode("2.0", forKey: .jsonrpc)
        try container.encode(id, forKey: .id)
        try container.encode(error, forKey: .error)
    }
}

nonisolated enum GooseACPIncomingMessage: Decodable, Equatable, Sendable {
    case request(id: GooseACPRequestID, method: GooseACPMethod, params: JSONValue)
    case notification(method: GooseACPMethod, params: JSONValue)
    case response(id: GooseACPRequestID, result: JSONValue)
    case error(id: GooseACPRequestID?, error: GooseACPJSONRPCError)

    private enum CodingKeys: String, CodingKey {
        case jsonrpc
        case id
        case method
        case params
        case result
        case error
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let method = try container.decodeIfPresent(String.self, forKey: .method) {
            let params = (try? container.decodeIfPresent(JSONValue.self, forKey: .params)) ?? .object([:])
            let parsedMethod = GooseACPMethod(rawValue: method)
            if let id = try container.decodeIfPresent(GooseACPRequestID.self, forKey: .id) {
                self = .request(id: id, method: parsedMethod, params: params)
            } else {
                self = .notification(method: parsedMethod, params: params)
            }
            return
        }

        if let error = try container.decodeIfPresent(GooseACPJSONRPCError.self, forKey: .error) {
            self = .error(
                id: try container.decodeIfPresent(GooseACPRequestID.self, forKey: .id),
                error: error
            )
            return
        }

        if let id = try container.decodeIfPresent(GooseACPRequestID.self, forKey: .id) {
            let result = (try? container.decodeIfPresent(JSONValue.self, forKey: .result)) ?? .object([:])
            self = .response(id: id, result: result)
            return
        }

        throw DecodingError.dataCorruptedError(
            forKey: .jsonrpc,
            in: container,
            debugDescription: "ACP message must be a JSON-RPC request, notification, or response"
        )
    }
}

nonisolated struct GooseACPJSONRPCError: Codable, Equatable, Sendable {
    let code: Int
    let message: String
    let data: JSONValue?

    static func unsupportedRequest(_ method: GooseACPMethod) -> Self {
        Self(
            code: -32601,
            message: "Unsupported ACP request: \(method.rawValue)",
            data: nil
        )
    }
}

nonisolated struct GooseACPInitializeRequest: Encodable, Equatable, Sendable {
    let protocolVersion: Int
    let clientCapabilities: GooseACPClientCapabilities
    let clientInfo: GooseACPImplementation

    static func epistemos(clientVersion: String) -> Self {
        Self(
            protocolVersion: 1,
            clientCapabilities: .epistemos,
            clientInfo: GooseACPImplementation(name: "Epistemos", version: clientVersion)
        )
    }
}

nonisolated struct GooseACPInitializeResponse: Decodable, Equatable, Sendable {
    let protocolVersion: Int
    let agentCapabilities: JSONValue?
    let agentInfo: GooseACPImplementation?
}

nonisolated struct GooseACPImplementation: Codable, Equatable, Sendable {
    let name: String
    let version: String
}

nonisolated struct GooseACPClientCapabilities: Encodable, Equatable, Sendable {
    let elicitation: GooseACPElicitationCapabilities
    let meta: [String: JSONValue]

    static let epistemos = Self(
        elicitation: GooseACPElicitationCapabilities(form: [:]),
        meta: [
            "goose": .object([
                "customNotifications": .bool(true),
                "recipeParameterRequests": .bool(true),
            ])
        ]
    )

    private enum CodingKeys: String, CodingKey {
        case elicitation
        case meta = "_meta"
    }
}

nonisolated struct GooseACPElicitationCapabilities: Codable, Equatable, Sendable {
    let form: [String: JSONValue]
}

nonisolated enum GooseACPCustomMethod: String, Sendable {
    case configExtensionsList = "_goose/unstable/config/extensions/list"
    case providerConfigRead = "_goose/unstable/providers/config/read"
    case providerConfigStatus = "_goose/unstable/providers/config/status"
    case providerConfigSave = "_goose/unstable/providers/config/save"
    case providerConfigDelete = "_goose/unstable/providers/config/delete"
    case providerConfigAuthenticate = "_goose/unstable/providers/config/authenticate"
    case providerSupportedModelsList = "_goose/unstable/providers/supported-models/list"
    case providerCatalogList = "_goose/unstable/providers/catalog/list"
    case providerCatalogTemplate = "_goose/unstable/providers/catalog/template"
    case providerSetupCatalogList = "_goose/unstable/providers/setup/catalog/list"
    case providersList = "_goose/unstable/providers/list"
    case preferencesRead = "_goose/unstable/preferences/read"
    case preferencesSave = "_goose/unstable/preferences/save"
    case preferencesRemove = "_goose/unstable/preferences/remove"
    case defaultsRead = "_goose/unstable/defaults/read"
    case defaultsSave = "_goose/unstable/defaults/save"
    case sourcesCreate = "_goose/unstable/sources/create"
    case sourcesList = "_goose/unstable/sources/list"
    case sourcesUpdate = "_goose/unstable/sources/update"
    case sourcesDelete = "_goose/unstable/sources/delete"
    case sourcesExport = "_goose/unstable/sources/export"
    case sourcesImport = "_goose/unstable/sources/import"
    case sessionInfo = "_goose/unstable/session/info"
    case diagnosticsGet = "_goose/unstable/diagnostics/get"
}

nonisolated struct GooseACPEmptyResponse: Decodable, Equatable, Sendable {}

nonisolated struct GooseACPProvidersListRequest: Encodable, Equatable, Sendable {
    let providerIds: [String]

    init(providerIds: [String] = []) {
        self.providerIds = providerIds
    }
}

nonisolated struct GooseACPProvidersListResponse: Decodable, Equatable, Sendable {
    let entries: [JSONValue]
}

/// One model id within a `providers/list` entry (the entries carry their models inline).
nonisolated struct GooseACPProviderInventoryModel: Decodable, Equatable, Sendable {
    let id: String
}

/// A typed view of a single `providers/list` entry — the available providers a Models picker chooses
/// among, each with its models inline (so no per-provider live enumeration that could hang), a
/// `configured` flag, and the provider's own default model. Decoded from the loosely-typed
/// `GooseACPProvidersListResponse.entries`. Unknown/missing fields degrade gracefully so a Goose
/// version that adds or drops entry fields never breaks the native picker.
nonisolated struct GooseACPProviderInventoryEntry: Decodable, Equatable, Sendable, Identifiable {
    let providerId: String
    let providerName: String
    let configured: Bool
    let defaultModel: String?
    let models: [GooseACPProviderInventoryModel]

    var id: String { providerId }

    private enum CodingKeys: String, CodingKey {
        case providerId
        case providerName
        case configured
        case defaultModel
        case models
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        providerId = try container.decode(String.self, forKey: .providerId)
        providerName = try container.decodeIfPresent(String.self, forKey: .providerName) ?? providerId
        configured = try container.decodeIfPresent(Bool.self, forKey: .configured) ?? false
        defaultModel = try container.decodeIfPresent(String.self, forKey: .defaultModel)
        models = try container.decodeIfPresent([GooseACPProviderInventoryModel].self, forKey: .models) ?? []
    }
}

nonisolated struct GooseACPProviderSupportedModelsListRequest: Encodable, Equatable, Sendable {
    let providerId: String
}

nonisolated struct GooseACPProviderSupportedModelsListResponse: Decodable, Equatable, Sendable {
    let providerId: String
    let models: [String]
}

nonisolated struct GooseACPProviderCatalogListRequest: Encodable, Equatable, Sendable {
    let format: String?

    init(format: String? = nil) {
        self.format = format
    }
}

nonisolated struct GooseACPProviderTemplateCatalogEntry: Decodable, Equatable, Sendable {
    let providerId: String
    let name: String
    let format: String
    let apiUrl: String
    let modelCount: Int
    let docUrl: String
    let envVar: String
}

nonisolated struct GooseACPProviderCatalogListResponse: Decodable, Equatable, Sendable {
    let providers: [GooseACPProviderTemplateCatalogEntry]
}

nonisolated struct GooseACPProviderCatalogTemplateRequest: Encodable, Equatable, Sendable {
    let providerId: String
}

nonisolated struct GooseACPProviderTemplateModelCapabilities: Decodable, Equatable, Sendable {
    let toolCall: Bool
    let reasoning: Bool
    let attachment: Bool
    let temperature: Bool
}

nonisolated struct GooseACPProviderTemplateModel: Decodable, Equatable, Sendable {
    let id: String
    let name: String
    let contextLimit: Int
    let capabilities: GooseACPProviderTemplateModelCapabilities
    let deprecated: Bool
}

nonisolated struct GooseACPProviderTemplate: Decodable, Equatable, Sendable {
    let providerId: String
    let name: String
    let format: String
    let apiUrl: String
    let models: [GooseACPProviderTemplateModel]
    let supportsStreaming: Bool
    let envVar: String
    let docUrl: String
}

nonisolated struct GooseACPProviderCatalogTemplateResponse: Decodable, Equatable, Sendable {
    let template: GooseACPProviderTemplate
}

nonisolated struct GooseACPProviderSetupCatalogListRequest: Encodable, Equatable, Sendable {}

nonisolated struct GooseACPProviderSetupField: Decodable, Equatable, Sendable {
    let key: String
    let label: String
    let secret: Bool
    let required: Bool
    let placeholder: String?
    let defaultValue: String?
}

nonisolated struct GooseACPProviderSetupCatalogEntry: Decodable, Equatable, Sendable {
    let providerId: String
    let name: String
    let category: String
    let description: String
    let setupMethod: String
    let nativeConnectQuery: String?
    let fields: [GooseACPProviderSetupField]
    let binaryName: String?
    let docUrl: String?
    let group: String
    let showOnlyWhenInstalled: Bool
    let aliases: [String]
    let supportsInstall: Bool
    let supportsAuth: Bool
    let supportsAuthStatus: Bool

    private enum CodingKeys: String, CodingKey {
        case providerId
        case name
        case category
        case description
        case setupMethod
        case nativeConnectQuery
        case fields
        case binaryName
        case docUrl
        case group
        case showOnlyWhenInstalled
        case aliases
        case supportsInstall
        case supportsAuth
        case supportsAuthStatus
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        providerId = try container.decode(String.self, forKey: .providerId)
        name = try container.decode(String.self, forKey: .name)
        category = try container.decode(String.self, forKey: .category)
        description = try container.decode(String.self, forKey: .description)
        setupMethod = try container.decode(String.self, forKey: .setupMethod)
        nativeConnectQuery = try container.decodeIfPresent(String.self, forKey: .nativeConnectQuery)
        fields = try container.decodeIfPresent([GooseACPProviderSetupField].self, forKey: .fields) ?? []
        binaryName = try container.decodeIfPresent(String.self, forKey: .binaryName)
        docUrl = try container.decodeIfPresent(String.self, forKey: .docUrl)
        group = try container.decode(String.self, forKey: .group)
        showOnlyWhenInstalled = try container.decode(Bool.self, forKey: .showOnlyWhenInstalled)
        aliases = try container.decodeIfPresent([String].self, forKey: .aliases) ?? []
        supportsInstall = try container.decode(Bool.self, forKey: .supportsInstall)
        supportsAuth = try container.decode(Bool.self, forKey: .supportsAuth)
        supportsAuthStatus = try container.decode(Bool.self, forKey: .supportsAuthStatus)
    }
}

nonisolated struct GooseACPProviderSetupCatalogListResponse: Decodable, Equatable, Sendable {
    let providers: [GooseACPProviderSetupCatalogEntry]
}

nonisolated struct GooseACPProviderConfigReadRequest: Encodable, Equatable, Sendable {
    let providerId: String
}

nonisolated struct GooseACPProviderConfigFieldValue: Codable, Equatable, Sendable {
    let key: String
    let value: String?
    let isSet: Bool
    let isSecret: Bool
    let required: Bool

    init(key: String, value: String?, isSet: Bool, isSecret: Bool, required: Bool) {
        self.key = key
        self.value = value
        self.isSet = isSet
        self.isSecret = isSecret
        self.required = required
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.key = try container.decode(String.self, forKey: .key)
        self.value = try container.decodeIfPresent(String.self, forKey: .value)
        self.isSet = try container.decodeIfPresent(Bool.self, forKey: .isSet) ?? false
        self.isSecret = try container.decodeIfPresent(Bool.self, forKey: .isSecret) ?? false
        self.required = try container.decodeIfPresent(Bool.self, forKey: .required) ?? false
    }
}

nonisolated struct GooseACPProviderConfigReadResponse: Decodable, Equatable, Sendable {
    let fields: [GooseACPProviderConfigFieldValue]
}

nonisolated struct GooseACPProviderConfigStatusRequest: Encodable, Equatable, Sendable {
    let providerIds: [String]

    init(providerIds: [String] = []) {
        self.providerIds = providerIds
    }
}

nonisolated struct GooseACPProviderConfigStatus: Codable, Equatable, Sendable {
    let providerId: String
    let isConfigured: Bool
}

nonisolated struct GooseACPProviderConfigStatusResponse: Decodable, Equatable, Sendable {
    let statuses: [GooseACPProviderConfigStatus]
}

nonisolated struct GooseACPProviderConfigFieldUpdate: Encodable, Equatable, Sendable {
    let key: String
    let value: String
}

nonisolated struct GooseACPProviderConfigSaveRequest: Encodable, Equatable, Sendable {
    let providerId: String
    let fields: [GooseACPProviderConfigFieldUpdate]
}

nonisolated struct GooseACPProviderConfigDeleteRequest: Encodable, Equatable, Sendable {
    let providerId: String
}

nonisolated struct GooseACPProviderConfigAuthenticateRequest: Encodable, Equatable, Sendable {
    let providerId: String
}

nonisolated struct GooseACPProviderConfigChangeResponse: Decodable, Equatable, Sendable {
    let status: GooseACPProviderConfigStatus
    let refresh: JSONValue
}

nonisolated struct GooseACPConfigExtensionsListRequest: Encodable, Equatable, Sendable {}

nonisolated struct GooseACPConfigExtensionsListResponse: Decodable, Equatable, Sendable {
    let extensions: [JSONValue]
    let warnings: [String]

    private enum CodingKeys: String, CodingKey {
        case extensions
        case warnings
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        extensions = try container.decode([JSONValue].self, forKey: .extensions)
        warnings = try container.decodeIfPresent([String].self, forKey: .warnings) ?? []
    }
}

nonisolated enum GooseACPPreferenceKey: String, Codable, Equatable, Sendable {
    case autoCompactThreshold
    case gooseThinkingEffort
    case voiceAutoSubmitPhrases
    case voiceDictationProvider
    case voiceDictationPreferredMic
}

nonisolated struct GooseACPPreferencesReadRequest: Encodable, Equatable, Sendable {
    let keys: [GooseACPPreferenceKey]

    init(keys: [GooseACPPreferenceKey] = []) {
        self.keys = keys
    }
}

nonisolated struct GooseACPPreferenceValue: Codable, Equatable, Sendable {
    let key: GooseACPPreferenceKey
    let value: JSONValue
}

nonisolated struct GooseACPPreferencesReadResponse: Decodable, Equatable, Sendable {
    let values: [GooseACPPreferenceValue]
}

nonisolated struct GooseACPPreferencesSaveRequest: Encodable, Equatable, Sendable {
    let values: [GooseACPPreferenceValue]
}

nonisolated struct GooseACPPreferencesRemoveRequest: Encodable, Equatable, Sendable {
    let keys: [GooseACPPreferenceKey]
}

nonisolated struct GooseACPDefaultsReadRequest: Encodable, Equatable, Sendable {}

nonisolated struct GooseACPDefaultsReadResponse: Decodable, Equatable, Sendable {
    let providerId: String?
    let modelId: String?
}

nonisolated struct GooseACPDefaultsSaveRequest: Encodable, Equatable, Sendable {
    let providerId: String
    let modelId: String?
}

nonisolated struct GooseACPSessionInfoRequest: Encodable, Equatable, Sendable {
    let sessionId: String
}

nonisolated struct GooseACPSessionInfoResponse: Decodable, Equatable, Sendable {
    let session: JSONValue
}

nonisolated struct GooseACPSessionInfo: Decodable, Equatable, Sendable {
    let sessionId: String
    let cwd: String
    let additionalDirectories: [String]?
    let title: String?
    let updatedAt: String?
    let metadata: JSONValue?

    private enum CodingKeys: String, CodingKey {
        case sessionId
        case cwd
        case additionalDirectories
        case title
        case updatedAt
        case metadata = "_meta"
    }
}

nonisolated struct GooseACPListSessionsRequest: Encodable, Equatable, Sendable {
    let cwd: String?
    let additionalDirectories: [String]?
    let cursor: String?
    let metadata: [String: JSONValue]?

    init(
        cursor: String? = nil,
        cwd: String? = nil,
        additionalDirectories: [String]? = nil,
        metadata: [String: JSONValue]? = nil
    ) {
        self.cwd = cwd
        self.additionalDirectories = additionalDirectories
        self.cursor = cursor
        self.metadata = metadata
    }

    private enum CodingKeys: String, CodingKey {
        case cwd
        case additionalDirectories
        case cursor
        case metadata = "_meta"
    }
}

nonisolated struct GooseACPListSessionsResponse: Decodable, Equatable, Sendable {
    let sessions: [GooseACPSessionInfo]
    let nextCursor: String?
    let metadata: JSONValue?

    private enum CodingKeys: String, CodingKey {
        case sessions
        case nextCursor
        case metadata = "_meta"
    }
}

nonisolated struct GooseACPLoadSessionRequest: Encodable, Equatable, Sendable {
    let mcpServers: [JSONValue]
    let cwd: String
    let additionalDirectories: [String]?
    let sessionId: String
    let metadata: [String: JSONValue]?

    init(
        sessionId: String,
        cwd: String,
        mcpServers: [JSONValue] = [],
        additionalDirectories: [String]? = nil,
        metadata: [String: JSONValue]? = nil
    ) {
        self.mcpServers = mcpServers
        self.cwd = cwd
        self.additionalDirectories = additionalDirectories
        self.sessionId = sessionId
        self.metadata = metadata
    }

    private enum CodingKeys: String, CodingKey {
        case mcpServers
        case cwd
        case additionalDirectories
        case sessionId
        case metadata = "_meta"
    }
}

nonisolated struct GooseACPLoadSessionResponse: Decodable, Equatable, Sendable {
    let modes: JSONValue?
    let models: JSONValue?
    let configOptions: JSONValue?
    let metadata: JSONValue?

    private enum CodingKeys: String, CodingKey {
        case modes
        case models
        case configOptions
        case metadata = "_meta"
    }
}

nonisolated struct GooseACPForkSessionRequest: Encodable, Equatable, Sendable {
    let sessionId: String
    let cwd: String
    let additionalDirectories: [String]?
    let metadata: [String: JSONValue]?

    init(
        sessionId: String,
        cwd: String,
        additionalDirectories: [String]? = nil,
        conversationBefore: Int? = nil,
        metadata: [String: JSONValue]? = nil
    ) {
        self.sessionId = sessionId
        self.cwd = cwd
        self.additionalDirectories = additionalDirectories
        if let conversationBefore {
            var merged = metadata ?? [:]
            merged["conversationBefore"] = .int(conversationBefore)
            self.metadata = merged
        } else {
            self.metadata = metadata
        }
    }

    private enum CodingKeys: String, CodingKey {
        case sessionId
        case cwd
        case additionalDirectories
        case metadata = "_meta"
    }
}

nonisolated struct GooseACPForkSessionResponse: Decodable, Equatable, Sendable {
    let sessionId: String
    let modes: JSONValue?
    let models: JSONValue?
    let configOptions: JSONValue?
    let metadata: JSONValue?

    private enum CodingKeys: String, CodingKey {
        case sessionId
        case modes
        case models
        case configOptions
        case metadata = "_meta"
    }
}

nonisolated enum GooseACPDiagnosticsLevel: String, Codable, Equatable, Sendable {
    case summary
    case full
}

nonisolated struct GooseACPDiagnosticsGetRequest: Encodable, Equatable, Sendable {
    let sessionId: String
    let level: GooseACPDiagnosticsLevel
}

nonisolated struct GooseACPDiagnosticsGetResponse: Decodable, Equatable, Sendable {
    let report: JSONValue
}

nonisolated struct GooseACPNewSessionRequest: Encodable, Equatable, Sendable {
    let cwd: String
    let mcpServers: [JSONValue]
    let metadata: [String: JSONValue]?

    init(cwd: String, mcpServers: [JSONValue] = [], metadata: [String: JSONValue]? = nil) {
        self.cwd = cwd
        self.mcpServers = mcpServers
        self.metadata = metadata
    }

    private enum CodingKeys: String, CodingKey {
        case cwd
        case mcpServers
        case metadata = "_meta"
    }
}

nonisolated struct GooseACPNewSessionResponse: Decodable, Equatable, Sendable {
    let sessionId: String
}

nonisolated struct GooseACPPromptRequest: Encodable, Equatable, Sendable {
    let sessionId: String
    let prompt: [GooseACPContentBlock]
}

nonisolated struct GooseACPPromptResponse: Decodable, Equatable, Sendable {
    let stopReason: GooseACPStopReason
}

nonisolated enum GooseACPStopReason: Codable, Equatable, Sendable {
    case endTurn
    case maxTokens
    case maxTurnRequests
    case refusal
    case cancelled
    case unknown(String)

    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        switch value {
        case "end_turn":
            self = .endTurn
        case "max_tokens":
            self = .maxTokens
        case "max_turn_requests":
            self = .maxTurnRequests
        case "refusal":
            self = .refusal
        case "cancelled":
            self = .cancelled
        default:
            self = .unknown(value)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    var rawValue: String {
        switch self {
        case .endTurn:
            "end_turn"
        case .maxTokens:
            "max_tokens"
        case .maxTurnRequests:
            "max_turn_requests"
        case .refusal:
            "refusal"
        case .cancelled:
            "cancelled"
        case .unknown(let raw):
            raw
        }
    }
}

nonisolated enum GooseACPContentBlock: Codable, Equatable, Sendable {
    case text(String)
    case image(data: String, mimeType: String)
    case unknown(JSONValue)

    private enum CodingKeys: String, CodingKey {
        case type
        case text
        case data
        case mimeType
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(String.self, forKey: .type) {
        case "text":
            self = .text(try container.decode(String.self, forKey: .text))
        case "image":
            self = .image(
                data: try container.decode(String.self, forKey: .data),
                mimeType: try container.decode(String.self, forKey: .mimeType)
            )
        default:
            self = .unknown(try JSONValue(from: decoder))
        }
    }

    func encode(to encoder: Encoder) throws {
        switch self {
        case .text(let text):
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode("text", forKey: .type)
            try container.encode(text, forKey: .text)
        case .image(let data, let mimeType):
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode("image", forKey: .type)
            try container.encode(data, forKey: .data)
            try container.encode(mimeType, forKey: .mimeType)
        case .unknown(let raw):
            try raw.encode(to: encoder)
        }
    }
}

nonisolated struct GooseACPContentChunk: Codable, Equatable, Sendable {
    let content: GooseACPContentBlock
}

nonisolated struct GooseACPSessionNotification: Codable, Equatable, Sendable {
    let sessionId: String
    let update: GooseACPSessionUpdate
}

nonisolated enum GooseACPSessionUpdate: Codable, Equatable, Sendable {
    case userMessageChunk(GooseACPContentChunk)
    case agentMessageChunk(GooseACPContentChunk)
    case agentThoughtChunk(GooseACPContentChunk)
    case toolCall(GooseACPToolCall)
    case toolCallUpdate(GooseACPToolCallUpdate)
    case sessionInfoUpdate(JSONValue)
    case usageUpdate(JSONValue)
    case unknown(kind: String, payload: JSONValue)

    private enum CodingKeys: String, CodingKey {
        case sessionUpdate
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(String.self, forKey: .sessionUpdate)
        switch kind {
        case "user_message_chunk":
            self = .userMessageChunk(try GooseACPContentChunk(from: decoder))
        case "agent_message_chunk":
            self = .agentMessageChunk(try GooseACPContentChunk(from: decoder))
        case "agent_thought_chunk":
            self = .agentThoughtChunk(try GooseACPContentChunk(from: decoder))
        case "tool_call":
            self = .toolCall(try GooseACPToolCall(from: decoder))
        case "tool_call_update":
            self = .toolCallUpdate(try GooseACPToolCallUpdate(from: decoder))
        case "session_info_update":
            self = .sessionInfoUpdate(try JSONValue(from: decoder))
        case "usage_update":
            self = .usageUpdate(try JSONValue(from: decoder))
        default:
            self = .unknown(kind: kind, payload: try JSONValue(from: decoder))
        }
    }

    func encode(to encoder: Encoder) throws {
        switch self {
        case .userMessageChunk(let chunk):
            try encode(kind: "user_message_chunk", value: chunk, to: encoder)
        case .agentMessageChunk(let chunk):
            try encode(kind: "agent_message_chunk", value: chunk, to: encoder)
        case .agentThoughtChunk(let chunk):
            try encode(kind: "agent_thought_chunk", value: chunk, to: encoder)
        case .toolCall(let call):
            try encode(kind: "tool_call", value: call, to: encoder)
        case .toolCallUpdate(let update):
            try encode(kind: "tool_call_update", value: update, to: encoder)
        case .sessionInfoUpdate(let raw), .usageUpdate(let raw), .unknown(_, let raw):
            try raw.encode(to: encoder)
        }
    }

    private func encode<T: Encodable>(kind: String, value: T, to encoder: Encoder) throws {
        let data = try JSONEncoder().encode(value)
        var raw = try JSONDecoder().decode([String: JSONValue].self, from: data)
        raw["sessionUpdate"] = .string(kind)
        try JSONValue.object(raw).encode(to: encoder)
    }
}

nonisolated struct GooseACPToolCall: Codable, Equatable, Sendable {
    let toolCallId: String
    let title: String
    let kind: GooseACPToolKind?
    let status: GooseACPToolCallStatus?
}

nonisolated struct GooseACPToolCallUpdate: Codable, Equatable, Sendable {
    let toolCallId: String
    let title: String?
    let kind: GooseACPToolKind?
    let status: GooseACPToolCallStatus?
}

nonisolated enum GooseACPToolKind: Codable, Equatable, Sendable {
    case read
    case edit
    case delete
    case move
    case search
    case execute
    case think
    case fetch
    case switchMode
    case other

    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        switch value {
        case "read":
            self = .read
        case "edit":
            self = .edit
        case "delete":
            self = .delete
        case "move":
            self = .move
        case "search":
            self = .search
        case "execute":
            self = .execute
        case "think":
            self = .think
        case "fetch":
            self = .fetch
        case "switch_mode":
            self = .switchMode
        default:
            self = .other
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    var rawValue: String {
        switch self {
        case .read:
            "read"
        case .edit:
            "edit"
        case .delete:
            "delete"
        case .move:
            "move"
        case .search:
            "search"
        case .execute:
            "execute"
        case .think:
            "think"
        case .fetch:
            "fetch"
        case .switchMode:
            "switch_mode"
        case .other:
            "other"
        }
    }
}

nonisolated enum GooseACPToolCallStatus: String, Codable, Equatable, Sendable {
    case pending
    case inProgress = "in_progress"
    case completed
    case failed
}

nonisolated struct GooseACPRequestPermissionRequest: Codable, Equatable, Sendable {
    let sessionId: String
    let toolCall: GooseACPToolCallUpdate
    let options: [GooseACPPermissionOption]

    func option(for kind: GooseACPPermissionOptionKind) -> GooseACPPermissionOption? {
        options.first { $0.kind == kind }
    }
}

nonisolated struct GooseACPPermissionOption: Codable, Equatable, Sendable {
    let optionId: String
    let name: String
    let kind: GooseACPPermissionOptionKind
}

nonisolated enum GooseACPPermissionOptionKind: String, Codable, Equatable, Sendable {
    case allowOnce = "allow_once"
    case allowAlways = "allow_always"
    case rejectOnce = "reject_once"
    case rejectAlways = "reject_always"
}

nonisolated struct GooseACPRequestPermissionResponse: Codable, Equatable, Sendable {
    let outcome: GooseACPPermissionOutcome

    static func selected(optionId: String) -> Self {
        Self(outcome: .selected(optionId: optionId))
    }

    static func cancelled() -> Self {
        Self(outcome: .cancelled)
    }
}

nonisolated enum GooseACPPermissionOutcome: Codable, Equatable, Sendable {
    case selected(optionId: String)
    case cancelled

    private enum CodingKeys: String, CodingKey {
        case outcome
        case optionId
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(String.self, forKey: .outcome) {
        case "selected":
            self = .selected(optionId: try container.decode(String.self, forKey: .optionId))
        case "cancelled":
            self = .cancelled
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .outcome,
                in: container,
                debugDescription: "unknown permission outcome"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .selected(let optionId):
            try container.encode("selected", forKey: .outcome)
            try container.encode(optionId, forKey: .optionId)
        case .cancelled:
            try container.encode("cancelled", forKey: .outcome)
        }
    }
}

nonisolated struct GooseACPCreateElicitationRequest: Codable, Equatable, Sendable {
    let mode: GooseACPElicitationMode
    let sessionId: String?
    let message: String
    let requestedSchema: JSONValue
}

nonisolated enum GooseACPElicitationMode: String, Codable, Equatable, Sendable {
    case form
    case url
}

nonisolated struct GooseACPCreateElicitationResponse: Codable, Equatable, Sendable {
    let action: String
    let content: [String: JSONValue]?

    static func accept(_ content: [String: JSONValue]) -> Self {
        Self(action: "accept", content: content)
    }

    static func decline() -> Self {
        Self(action: "decline", content: nil)
    }

    static func cancel() -> Self {
        Self(action: "cancel", content: nil)
    }
}

extension JSONValue {
    nonisolated func decoded<T: Decodable>(_ type: T.Type) throws -> T {
        let data = try JSONEncoder().encode(self)
        return try JSONDecoder().decode(type, from: data)
    }
}
