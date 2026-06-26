import Foundation

public indirect enum ChatDonorMCPValue: Codable, Hashable, Sendable, ExpressibleByStringLiteral, ExpressibleByIntegerLiteral, ExpressibleByBooleanLiteral, ExpressibleByArrayLiteral, ExpressibleByDictionaryLiteral {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([ChatDonorMCPValue])
    case object([String: ChatDonorMCPValue])

    public init(stringLiteral value: String) {
        self = .string(value)
    }

    public init(integerLiteral value: Int) {
        self = .number(Double(value))
    }

    public init(booleanLiteral value: Bool) {
        self = .bool(value)
    }

    public init(arrayLiteral elements: ChatDonorMCPValue...) {
        self = .array(elements)
    }

    public init(dictionaryLiteral elements: (String, ChatDonorMCPValue)...) {
        self = .object(Dictionary(uniqueKeysWithValues: elements))
    }

    public var stringValue: String? {
        if case .string(let value) = self { value } else { nil }
    }

    public var numberValue: Double? {
        if case .number(let value) = self { value } else { nil }
    }

    public var objectValue: [String: ChatDonorMCPValue]? {
        if case .object(let value) = self { value } else { nil }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let number = try? container.decode(Double.self) {
            self = .number(number)
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let array = try? container.decode([ChatDonorMCPValue].self) {
            self = .array(array)
        } else {
            self = .object(try container.decode([String: ChatDonorMCPValue].self))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null:
            try container.encodeNil()
        case .bool(let value):
            try container.encode(value)
        case .number(let value):
            try container.encode(value)
        case .string(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        }
    }
}

public struct ChatDonorMCPToolAnnotations: Codable, Hashable, Sendable, ExpressibleByNilLiteral {
    public var title: String?
    public var readOnlyHint: Bool?
    public var destructiveHint: Bool?
    public var idempotentHint: Bool?
    public var openWorldHint: Bool?

    public init(
        title: String? = nil,
        readOnlyHint: Bool? = nil,
        destructiveHint: Bool? = nil,
        idempotentHint: Bool? = nil,
        openWorldHint: Bool? = nil
    ) {
        self.title = title
        self.readOnlyHint = readOnlyHint
        self.destructiveHint = destructiveHint
        self.idempotentHint = idempotentHint
        self.openWorldHint = openWorldHint
    }

    public init(nilLiteral: ()) {}

    public var isEmpty: Bool {
        title == nil &&
            readOnlyHint == nil &&
            destructiveHint == nil &&
            idempotentHint == nil &&
            openWorldHint == nil
    }

    public var requiresExplicitApproval: Bool {
        readOnlyHint != true || destructiveHint == true || openWorldHint == true
    }
}

public struct ChatDonorMCPToolDescriptor: Codable, Hashable, Sendable {
    public var name: String
    public var title: String?
    public var description: String?
    public var inputSchema: ChatDonorMCPValue
    public var outputSchema: ChatDonorMCPValue?
    public var annotations: ChatDonorMCPToolAnnotations
    public var metadata: [String: ChatDonorMCPValue]

    public init(
        name: String,
        title: String? = nil,
        description: String? = nil,
        inputSchema: ChatDonorMCPValue = .object(["type": "object"]),
        outputSchema: ChatDonorMCPValue? = nil,
        annotations: ChatDonorMCPToolAnnotations = nil,
        metadata: [String: ChatDonorMCPValue] = [:]
    ) {
        self.name = name
        self.title = title
        self.description = description
        self.inputSchema = inputSchema
        self.outputSchema = outputSchema
        self.annotations = annotations
        self.metadata = metadata
    }

    public var displayName: String {
        title ?? annotations.title ?? name
    }

    public var requiresExplicitApproval: Bool {
        annotations.requiresExplicitApproval
    }
}

public enum ChatDonorMCPContent: Codable, Hashable, Sendable {
    case text(String)
    case image(data: String, mimeType: String)
    case audio(data: String, mimeType: String)
    case resource(ChatDonorMCPResourceContent)
    case resourceLink(uri: String, name: String, title: String? = nil, description: String? = nil, mimeType: String? = nil)
}

public struct ChatDonorMCPToolResult: Codable, Hashable, Sendable {
    public var content: [ChatDonorMCPContent]
    public var isError: Bool

    public init(content: [ChatDonorMCPContent], isError: Bool = false) {
        self.content = content
        self.isError = isError
    }
}

public struct ChatDonorMCPResourceAnnotations: Codable, Hashable, Sendable {
    public enum Audience: String, Codable, Hashable, Sendable {
        case user
        case assistant
    }

    public var audience: [Audience]?
    public var priority: Double?
    public var lastModified: String?

    public init(
        audience: [Audience]? = nil,
        priority: Double? = nil,
        lastModified: String? = nil
    ) {
        self.audience = audience
        self.priority = priority.map { min(max($0, 0), 1) }
        self.lastModified = lastModified
    }
}

public struct ChatDonorMCPResourceDescriptor: Codable, Hashable, Sendable {
    public var name: String
    public var uri: String
    public var title: String?
    public var description: String?
    public var mimeType: String?
    public var size: Int?
    public var annotations: ChatDonorMCPResourceAnnotations?

    public init(
        name: String,
        uri: String,
        title: String? = nil,
        description: String? = nil,
        mimeType: String? = nil,
        size: Int? = nil,
        annotations: ChatDonorMCPResourceAnnotations? = nil
    ) {
        self.name = name
        self.uri = uri
        self.title = title
        self.description = description
        self.mimeType = mimeType
        self.size = size.map { max(0, $0) }
        self.annotations = annotations
    }
}

public struct ChatDonorMCPResourceContent: Codable, Hashable, Sendable {
    public var uri: String
    public var mimeType: String?
    public var text: String?
    public var blob: String?

    public static func text(_ content: String, uri: String, mimeType: String? = nil) -> ChatDonorMCPResourceContent {
        ChatDonorMCPResourceContent(uri: uri, mimeType: mimeType, text: content, blob: nil)
    }

    public static func binary(_ data: Data, uri: String, mimeType: String? = nil) -> ChatDonorMCPResourceContent {
        ChatDonorMCPResourceContent(uri: uri, mimeType: mimeType, text: nil, blob: data.base64EncodedString())
    }
}

public struct ChatDonorMCPResourceTemplate: Codable, Hashable, Sendable {
    public var uriTemplate: String
    public var name: String
    public var title: String?
    public var description: String?
    public var mimeType: String?

    public init(
        uriTemplate: String,
        name: String,
        title: String? = nil,
        description: String? = nil,
        mimeType: String? = nil
    ) {
        self.uriTemplate = uriTemplate
        self.name = name
        self.title = title
        self.description = description
        self.mimeType = mimeType
    }
}

public struct ChatDonorMCPPromptDescriptor: Codable, Hashable, Sendable {
    public var name: String
    public var title: String?
    public var description: String?
    public var arguments: [Argument]

    public struct Argument: Codable, Hashable, Sendable {
        public var name: String
        public var title: String?
        public var description: String?
        public var required: Bool?

        public init(
            name: String,
            title: String? = nil,
            description: String? = nil,
            required: Bool? = nil
        ) {
            self.name = name
            self.title = title
            self.description = description
            self.required = required
        }
    }

    public init(
        name: String,
        title: String? = nil,
        description: String? = nil,
        arguments: [Argument] = []
    ) {
        self.name = name
        self.title = title
        self.description = description
        self.arguments = arguments
    }

    public var requiredArgumentNames: [String] {
        arguments.filter { $0.required == true }.map(\.name)
    }

    public func missingRequiredArguments(in supplied: [String: String]) -> [String] {
        requiredArgumentNames.filter { supplied[$0] == nil }
    }
}

public struct ChatDonorMCPPromptMessage: Codable, Hashable, Sendable {
    public enum Role: String, Codable, Hashable, Sendable {
        case user
        case assistant
    }

    public var role: Role
    public var content: ChatDonorMCPContent

    public static func user(_ content: ChatDonorMCPContent) -> ChatDonorMCPPromptMessage {
        ChatDonorMCPPromptMessage(role: .user, content: content)
    }

    public static func assistant(_ content: ChatDonorMCPContent) -> ChatDonorMCPPromptMessage {
        ChatDonorMCPPromptMessage(role: .assistant, content: content)
    }
}

public enum ChatDonorMCPProgressToken: Codable, Hashable, Sendable {
    case string(String)
    case integer(Int)

    public static func unique() -> ChatDonorMCPProgressToken {
        .string(UUID().uuidString)
    }
}

public struct ChatDonorMCPProgressNotification: Codable, Hashable, Sendable {
    public static let method = "notifications/progress"

    public var token: ChatDonorMCPProgressToken
    public var progress: Double
    public var total: Double?
    public var message: String?

    public init(
        token: ChatDonorMCPProgressToken,
        progress: Double,
        total: Double? = nil,
        message: String? = nil
    ) {
        self.token = token
        self.progress = max(0, progress)
        self.total = total.map { max(0, $0) }
        self.message = message
    }

    public var fractionComplete: Double? {
        guard let total, total > 0 else { return nil }
        return min(progress / total, 1)
    }
}

public enum ChatDonorMCPProgressAppendResult: Codable, Hashable, Sendable {
    case appended(count: Int)
    case rejectedTokenMismatch
    case rejectedNonMonotonic
}

public struct ChatDonorMCPProgressTracker: Codable, Hashable, Sendable {
    public var token: ChatDonorMCPProgressToken
    public private(set) var notifications: [ChatDonorMCPProgressNotification]

    public init(token: ChatDonorMCPProgressToken, notifications: [ChatDonorMCPProgressNotification] = []) {
        self.token = token
        self.notifications = notifications.filter { $0.token == token }
    }

    @discardableResult
    public mutating func append(_ notification: ChatDonorMCPProgressNotification) -> ChatDonorMCPProgressAppendResult {
        guard notification.token == token else { return .rejectedTokenMismatch }
        if let last = notifications.last, notification.progress < last.progress {
            return .rejectedNonMonotonic
        }
        notifications.append(notification)
        return .appended(count: notifications.count)
    }
}

public struct ChatDonorMCPCancellationNotice: Codable, Hashable, Sendable {
    public static let method = "notifications/cancelled"

    public var requestID: String?
    public var reason: String?

    public init(requestID: String? = nil, reason: String? = nil) {
        self.requestID = requestID
        self.reason = reason
    }

    public func matches(requestID candidate: String) -> Bool {
        requestID == nil || requestID == candidate
    }
}

public enum ChatDonorMCPElicitationMode: String, Codable, Hashable, Sendable {
    case form
    case url
}

public struct ChatDonorMCPElicitationSchema: Codable, Hashable, Sendable {
    public var title: String?
    public var description: String?
    public var properties: [String: ChatDonorMCPValue]
    public var required: [String]

    public init(
        title: String? = nil,
        description: String? = nil,
        properties: [String: ChatDonorMCPValue] = [:],
        required: [String] = []
    ) {
        self.title = title
        self.description = description
        self.properties = properties
        self.required = required
    }

    public func missingRequiredFields(in content: [String: ChatDonorMCPValue]) -> [String] {
        required.filter { content[$0] == nil }
    }
}

public struct ChatDonorMCPElicitationRequest: Codable, Hashable, Sendable {
    public var message: String
    public var mode: ChatDonorMCPElicitationMode
    public var schema: ChatDonorMCPElicitationSchema?
    public var url: String?
    public var elicitationID: String?

    public static func form(
        message: String,
        schema: ChatDonorMCPElicitationSchema
    ) -> ChatDonorMCPElicitationRequest {
        ChatDonorMCPElicitationRequest(
            message: message,
            mode: .form,
            schema: schema,
            url: nil,
            elicitationID: nil
        )
    }

    public static func url(
        message: String,
        url: String,
        elicitationID: String
    ) -> ChatDonorMCPElicitationRequest {
        ChatDonorMCPElicitationRequest(
            message: message,
            mode: .url,
            schema: nil,
            url: url,
            elicitationID: elicitationID
        )
    }
}

public struct ChatDonorMCPElicitationResult: Codable, Hashable, Sendable {
    public enum Action: String, Codable, Hashable, Sendable {
        case accept
        case decline
        case cancel
    }

    public var action: Action
    public var content: [String: ChatDonorMCPValue]

    public init(action: Action, content: [String: ChatDonorMCPValue] = [:]) {
        self.action = action
        self.content = action == .accept ? content : [:]
    }
}

public struct ChatDonorMCPOAuthURLPolicy: Codable, Hashable, Sendable {
    public enum ValidationKind: String, Codable, Hashable, Sendable {
        case resourceEndpoint
        case authorizationServer
        case redirectURI
    }

    public enum Decision: Codable, Hashable, Sendable {
        case allowed
        case rejected(reason: String)
    }

    public var allowLoopbackHTTPAuthorizationServer: Bool

    public init(allowLoopbackHTTPAuthorizationServer: Bool = false) {
        self.allowLoopbackHTTPAuthorizationServer = allowLoopbackHTTPAuthorizationServer
    }

    public func validate(_ rawURL: String, kind: ValidationKind) -> Decision {
        guard let components = URLComponents(string: rawURL),
              let scheme = components.scheme?.lowercased(),
              let host = components.host?.lowercased(),
              !host.isEmpty,
              components.fragment == nil else {
            return .rejected(reason: "invalid-url")
        }

        switch kind {
        case .resourceEndpoint:
            if scheme == "https" || (scheme == "http" && Self.isLoopback(host)) {
                return .allowed
            }
            return .rejected(reason: "resource-endpoint-requires-https-or-loopback")

        case .authorizationServer:
            if scheme == "https" {
                return .allowed
            }
            if allowLoopbackHTTPAuthorizationServer, scheme == "http", Self.isLoopback(host) {
                return .allowed
            }
            return .rejected(reason: "authorization-server-requires-https")

        case .redirectURI:
            if scheme == "https" || (scheme == "http" && Self.isLoopback(host)) {
                return .allowed
            }
            return .rejected(reason: "redirect-uri-requires-https-or-loopback")
        }
    }

    public static func isPrivateIPHost(_ host: String) -> Bool {
        let octets = host.split(separator: ".").compactMap { UInt8($0) }
        if octets.count == 4 && !host.contains(":") {
            let first = octets[0]
            let second = octets[1]
            return first == 10 ||
                (first == 172 && (16...31).contains(second)) ||
                (first == 192 && second == 168) ||
                (first == 169 && second == 254) ||
                (first == 100 && (64...127).contains(second))
        }

        let lower = host.lowercased()
        if lower.hasPrefix("fc") || lower.hasPrefix("fd") { return true }
        if lower.hasPrefix("fe"), lower.count > 2 {
            let idx = lower.index(lower.startIndex, offsetBy: 2)
            return "89ab".contains(lower[idx])
        }
        return false
    }

    private static func isLoopback(_ host: String) -> Bool {
        host == "localhost" || host == "127.0.0.1" || host == "::1"
    }
}

public struct ChatDonorMCPOAuthToken: Codable, Hashable, Sendable {
    public var value: String
    public var tokenType: String
    public var expiresAt: Date?
    public var scopes: Set<String>
    public var authorizationServer: String?
    public var refreshToken: String?
    public var clientID: String?

    public init(
        value: String,
        tokenType: String = "Bearer",
        expiresAt: Date? = nil,
        scopes: Set<String> = [],
        authorizationServer: String? = nil,
        refreshToken: String? = nil,
        clientID: String? = nil
    ) {
        self.value = value
        self.tokenType = tokenType
        self.expiresAt = expiresAt
        self.scopes = scopes
        self.authorizationServer = authorizationServer
        self.refreshToken = refreshToken
        self.clientID = clientID
    }

    public func isExpired(now: Date = Date(), skewSeconds: TimeInterval = 30) -> Bool {
        guard let expiresAt else { return false }
        return now.addingTimeInterval(skewSeconds) >= expiresAt
    }
}
