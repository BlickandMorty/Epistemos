import Foundation

public enum ChatDonorAgentKitMCPTransportKind: String, Codable, Hashable, Sendable {
    case stdio
    case http
}

public enum ChatDonorAgentKitMCPTimeoutDecision: Codable, Hashable, Sendable {
    case unspecified
    case valid(milliseconds: Int)
    case invalidNonPositive

    public var canStart: Bool {
        switch self {
        case .unspecified, .valid:
            true
        case .invalidNonPositive:
            false
        }
    }
}

public enum ChatDonorAgentKitMCPConfigurationFailure: String, Codable, Hashable, Sendable {
    case emptyName = "empty-name"
    case emptyCommand = "empty-command"
    case malformedURL = "malformed-url"
    case invalidTimeout = "invalid-timeout"
    case disabled = "disabled"
}

public enum ChatDonorAgentKitMCPError: Error, Hashable, Sendable, LocalizedError {
    case missingParameter(String)
    case unknownTool(String)
    case unknownPrompt(String)
    case resourceNotFound(String)
    case missingPromptValue(String)
    case missingPromptParameters([String])
    case extraPromptParameters([String])

    public var errorDescription: String? {
        switch self {
        case .missingParameter(let name):
            "Missing parameter \(name)"
        case .unknownTool(let name):
            "Unknown tool \(name)"
        case .unknownPrompt(let name):
            "Unknown prompt \(name)"
        case .resourceNotFound(let uri):
            "Resource not found: \(uri)"
        case .missingPromptValue(let name):
            "Missing value for parameter: \(name)"
        case .missingPromptParameters(let names):
            "Missing parameters: \(names.joined(separator: ", "))"
        case .extraPromptParameters(let names):
            "Extra parameters defined but not used in template: \(names.joined(separator: ", "))"
        }
    }
}

public enum ChatDonorAgentKitMCPTransport: Codable, Hashable, Sendable {
    case stdio(command: String, args: [String], env: [String: String])
    case http(url: String)

    public var kind: ChatDonorAgentKitMCPTransportKind {
        switch self {
        case .stdio:
            .stdio
        case .http:
            .http
        }
    }

    public var command: String? {
        if case .stdio(let command, _, _) = self { command } else { nil }
    }

    public var url: String? {
        if case .http(let url) = self { url } else { nil }
    }
}

public struct ChatDonorAgentKitMCPServerConfiguration: Codable, Hashable, Sendable {
    public var name: String
    public var transport: ChatDonorAgentKitMCPTransport
    public var disabled: Bool
    public var timeoutMilliseconds: Int?

    public init(
        name: String,
        transport: ChatDonorAgentKitMCPTransport,
        disabled: Bool = false,
        timeoutMilliseconds: Int? = nil
    ) {
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.transport = transport
        self.disabled = disabled
        self.timeoutMilliseconds = timeoutMilliseconds
    }

    public var timeoutDecision: ChatDonorAgentKitMCPTimeoutDecision {
        guard let timeoutMilliseconds else { return .unspecified }
        guard timeoutMilliseconds > 0 else { return .invalidNonPositive }
        return .valid(milliseconds: timeoutMilliseconds)
    }

    public var validationFailures: [ChatDonorAgentKitMCPConfigurationFailure] {
        var failures: [ChatDonorAgentKitMCPConfigurationFailure] = []
        if name.isEmpty {
            failures.append(.emptyName)
        }
        if disabled {
            failures.append(.disabled)
        }
        if !timeoutDecision.canStart {
            failures.append(.invalidTimeout)
        }
        switch transport {
        case .stdio(let command, _, _):
            if command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                failures.append(.emptyCommand)
            }
        case .http(let url):
            if URL(string: url) == nil {
                failures.append(.malformedURL)
            }
        }
        return failures
    }

    public var canStart: Bool {
        validationFailures.isEmpty
    }

    fileprivate var rawConfiguration: RawServerConfiguration {
        switch transport {
        case .stdio(let command, let args, let env):
            RawServerConfiguration(
                command: command,
                args: args.isEmpty ? nil : args,
                env: env.isEmpty ? nil : env,
                url: nil,
                disabled: disabled,
                timeout: timeoutMilliseconds
            )
        case .http(let url):
            RawServerConfiguration(
                command: nil,
                args: nil,
                env: nil,
                url: url,
                disabled: disabled,
                timeout: timeoutMilliseconds
            )
        }
    }

    fileprivate init(name: String, raw: RawServerConfiguration) throws {
        let transport: ChatDonorAgentKitMCPTransport
        if let command = raw.command {
            transport = .stdio(command: command, args: raw.args ?? [], env: raw.env ?? [:])
        } else if let url = raw.url {
            transport = .http(url: url)
        } else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: [],
                    debugDescription: "Unable to determine MCP server configuration type"
                )
            )
        }

        self.init(
            name: name,
            transport: transport,
            disabled: raw.disabled ?? false,
            timeoutMilliseconds: raw.timeout
        )
    }
}

public struct ChatDonorAgentKitMCPConfiguration: Codable, Hashable, Sendable {
    public var servers: [ChatDonorAgentKitMCPServerConfiguration]

    public init(servers: [ChatDonorAgentKitMCPServerConfiguration]) {
        self.servers = servers.sorted { $0.name < $1.name }
    }

    public var activeServers: [ChatDonorAgentKitMCPServerConfiguration] {
        servers.filter(\.canStart)
    }

    public subscript(serverName: String) -> ChatDonorAgentKitMCPServerConfiguration? {
        servers.first { $0.name == serverName }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawServers = try container.decode([String: RawServerConfiguration].self, forKey: .mcpServers)
        servers = try rawServers.map { name, raw in
            try ChatDonorAgentKitMCPServerConfiguration(name: name, raw: raw)
        }.sorted { $0.name < $1.name }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        let rawServers = Dictionary(uniqueKeysWithValues: servers.map { server in
            (server.name, server.rawConfiguration)
        })
        try container.encode(rawServers, forKey: .mcpServers)
    }

    private enum CodingKeys: String, CodingKey {
        case mcpServers
    }
}

private struct RawServerConfiguration: Codable, Hashable, Sendable {
    var command: String?
    var args: [String]?
    var env: [String: String]?
    var url: String?
    var disabled: Bool?
    var timeout: Int?
}

public struct ChatDonorAgentKitMCPClientDescriptor: Codable, Hashable, Sendable {
    public var name: String
    public var tools: [ChatDonorMCPToolDescriptor]

    public init(name: String, tools: [ChatDonorMCPToolDescriptor] = []) {
        self.name = name
        self.tools = tools
    }

    public func hasTool(named toolName: String) -> Bool {
        tools.contains { $0.name == toolName }
    }
}

public struct ChatDonorAgentKitMCPClientCatalog: Codable, Hashable, Sendable {
    public var clients: [ChatDonorAgentKitMCPClientDescriptor]

    public init(clients: [ChatDonorAgentKitMCPClientDescriptor] = []) {
        self.clients = clients
    }

    public func listToolNames() -> [String] {
        clients.flatMap { $0.tools.map(\.name) }
    }

    public func clientName(forTool toolName: String) -> String? {
        clients.first { $0.hasTool(named: toolName) }?.name
    }

    public func route(toolName: String, arguments: [String: ChatDonorMCPValue]) throws -> ChatDonorAgentKitMCPRoutedToolCall {
        guard let client = clients.first(where: { $0.hasTool(named: toolName) }),
              let tool = client.tools.first(where: { $0.name == toolName }) else {
            throw ChatDonorAgentKitMCPError.unknownTool(toolName)
        }
        return ChatDonorAgentKitMCPRoutedToolCall(
            clientName: client.name,
            tool: tool,
            arguments: arguments
        )
    }

    public func asToolWrappers() -> [ChatDonorAgentKitMCPToolWrapper] {
        clients.flatMap { client in
            client.tools.map { tool in
                ChatDonorAgentKitMCPToolWrapper(clientName: client.name, tool: tool)
            }
        }
    }
}

public struct ChatDonorAgentKitMCPRoutedToolCall: Codable, Hashable, Sendable {
    public var clientName: String
    public var tool: ChatDonorMCPToolDescriptor
    public var arguments: [String: ChatDonorMCPValue]

    public init(
        clientName: String,
        tool: ChatDonorMCPToolDescriptor,
        arguments: [String: ChatDonorMCPValue]
    ) {
        self.clientName = clientName
        self.tool = tool
        self.arguments = arguments
    }
}

public struct ChatDonorAgentKitMCPToolWrapper: Codable, Hashable, Sendable, CustomStringConvertible {
    public var clientName: String
    public var tool: ChatDonorMCPToolDescriptor

    public init(clientName: String, tool: ChatDonorMCPToolDescriptor) {
        self.clientName = clientName
        self.tool = tool
    }

    public var toolName: String {
        tool.name
    }

    public var toolDescription: String {
        tool.description ?? ""
    }

    public var inputSchemaJSONString: String {
        tool.inputSchema.agentKitStableJSONString
    }

    public var description: String {
        "MCPToolWrapper(\(toolName))"
    }
}

public enum ChatDonorAgentKitMCPToolInputDecoder {
    public static func decode<Input: Decodable & Sendable>(
        _ inputType: Input.Type,
        from arguments: [String: ChatDonorMCPValue],
        fallbackParameterName: String = "input"
    ) throws -> Input {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        if let decoded = try? decoder.decode(inputType, from: encoder.encode(arguments)) {
            return decoded
        }

        guard let fallback = arguments[fallbackParameterName] else {
            throw ChatDonorAgentKitMCPError.missingParameter(fallbackParameterName)
        }
        return try decoder.decode(inputType, from: encoder.encode(fallback))
    }
}

public struct ChatDonorAgentKitMCPServerCapabilities: Codable, Hashable, Sendable {
    public var tools: Bool
    public var prompts: Bool
    public var resources: Bool

    public init(tools: Bool = false, prompts: Bool = false, resources: Bool = false) {
        self.tools = tools
        self.prompts = prompts
        self.resources = resources
    }
}

public struct ChatDonorAgentKitMCPResource: Codable, Hashable, Sendable {
    public var descriptor: ChatDonorMCPResourceDescriptor
    public var content: ChatDonorMCPResourceContent

    public init(
        descriptor: ChatDonorMCPResourceDescriptor,
        content: ChatDonorMCPResourceContent
    ) {
        self.descriptor = descriptor
        self.content = content
    }

    public static func text(
        name: String,
        uri: String,
        content: String,
        description: String? = nil,
        mimeType: String = "text/plain"
    ) -> Self {
        Self(
            descriptor: ChatDonorMCPResourceDescriptor(
                name: name,
                uri: uri,
                description: description,
                mimeType: mimeType
            ),
            content: .text(content, uri: uri, mimeType: mimeType)
        )
    }

    public static func binary(
        name: String,
        uri: String,
        data: Data,
        description: String? = nil,
        mimeType: String? = nil
    ) -> Self {
        Self(
            descriptor: ChatDonorMCPResourceDescriptor(
                name: name,
                uri: uri,
                description: description,
                mimeType: mimeType,
                size: data.count
            ),
            content: .binary(data, uri: uri, mimeType: mimeType)
        )
    }
}

public struct ChatDonorAgentKitMCPPromptTemplate: Codable, Hashable, Sendable {
    public var name: String
    public var description: String
    public var template: String
    public var parameters: [String: String]

    public init(
        name: String,
        description: String,
        template: String,
        parameters: [String: String] = [:]
    ) throws {
        self.name = name
        self.description = description
        self.template = template
        self.parameters = parameters
        try validateParameters()
    }

    public var descriptor: ChatDonorMCPPromptDescriptor {
        ChatDonorMCPPromptDescriptor(
            name: name,
            description: description,
            arguments: parameters.keys.sorted().map { parameterName in
                ChatDonorMCPPromptDescriptor.Argument(
                    name: parameterName,
                    description: parameters[parameterName],
                    required: true
                )
            }
        )
    }

    public func render(with values: [String: String]) throws -> String {
        var rendered = template
        for parameter in parameters.keys.sorted() {
            guard let value = values[parameter] else {
                throw ChatDonorAgentKitMCPError.missingPromptValue(parameter)
            }
            rendered = rendered.replacingOccurrences(of: "{\(parameter)}", with: value)
        }
        return rendered
    }

    private func validateParameters() throws {
        let placeholders = Set(Self.placeholderNames(in: template))
        let parameterNames = Set(parameters.keys)
        let missing = placeholders.subtracting(parameterNames).sorted()
        if !missing.isEmpty {
            throw ChatDonorAgentKitMCPError.missingPromptParameters(missing)
        }
        let extra = parameterNames.subtracting(placeholders).sorted()
        if !extra.isEmpty {
            throw ChatDonorAgentKitMCPError.extraPromptParameters(extra)
        }
    }

    private static func placeholderNames(in template: String) -> [String] {
        var names: [String] = []
        var cursor = template.startIndex
        while let open = template[cursor...].firstIndex(of: "{") {
            guard let close = template[template.index(after: open)...].firstIndex(of: "}") else {
                break
            }
            let name = String(template[template.index(after: open)..<close])
            if !name.isEmpty {
                names.append(name)
            }
            cursor = template.index(after: close)
        }
        return names
    }
}

public struct ChatDonorAgentKitMCPServerDescriptor: Codable, Hashable, Sendable {
    public var name: String
    public var version: String
    public var transport: ChatDonorAgentKitMCPTransportKind
    public var tools: [ChatDonorMCPToolDescriptor]
    public var prompts: [ChatDonorAgentKitMCPPromptTemplate]
    public var resources: [ChatDonorAgentKitMCPResource]

    public init(
        name: String,
        version: String = "1.0.0",
        transport: ChatDonorAgentKitMCPTransportKind = .stdio,
        tools: [ChatDonorMCPToolDescriptor] = [],
        prompts: [ChatDonorAgentKitMCPPromptTemplate] = [],
        resources: [ChatDonorAgentKitMCPResource] = []
    ) {
        self.name = name
        self.version = version
        self.transport = transport
        self.tools = tools
        self.prompts = prompts
        self.resources = resources
    }

    public var capabilities: ChatDonorAgentKitMCPServerCapabilities {
        ChatDonorAgentKitMCPServerCapabilities(
            tools: !tools.isEmpty,
            prompts: !prompts.isEmpty,
            resources: !resources.isEmpty
        )
    }

    public mutating func registerResources(_ newResources: [ChatDonorAgentKitMCPResource]) {
        resources.append(contentsOf: newResources)
    }

    public func tool(named toolName: String) throws -> ChatDonorMCPToolDescriptor {
        guard let tool = tools.first(where: { $0.name == toolName }) else {
            throw ChatDonorAgentKitMCPError.unknownTool(toolName)
        }
        return tool
    }

    public func resourceContent(uri: String) throws -> ChatDonorMCPResourceContent {
        guard let resource = resources.first(where: { $0.descriptor.uri == uri }) else {
            throw ChatDonorAgentKitMCPError.resourceNotFound(uri)
        }
        return resource.content
    }

    public func renderPrompt(named promptName: String, arguments: [String: String]) throws -> String {
        guard let prompt = prompts.first(where: { $0.name == promptName }) else {
            throw ChatDonorAgentKitMCPError.unknownPrompt(promptName)
        }
        return try prompt.render(with: arguments)
    }
}

private extension ChatDonorMCPValue {
    var agentKitStableJSONString: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(self),
              let string = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return string
    }
}
