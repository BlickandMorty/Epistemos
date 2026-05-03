import Foundation

nonisolated struct OmegaToolDefinition {
    let name: String
    let agent: String
    let description: String
    let argumentsExample: String
    let schemaJson: String
    let destructive: Bool
    let requiresConfirmation: Bool

    var planningSchema: [String: Any] {
        var schema: [String: Any] = [
            "name": name,
            "description": description,
        ]
        if let data = schemaJson.data(using: .utf8),
           let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            schema["inputSchema"] = Self.normalizedPlanningInputSchema(parsed, isRoot: true)
        }
        return schema
    }

    private static func normalizedPlanningInputSchema(_ value: Any, isRoot: Bool = false) -> Any {
        if var object = value as? [String: Any] {
            let isObjectSchema = (object["type"] as? String) == "object"
            let hasProperties = object["properties"] is [String: Any]

            if isObjectSchema && (isRoot || hasProperties) && object["additionalProperties"] == nil {
                object["properties"] = (object["properties"] as? [String: Any]) ?? [:]
                object["additionalProperties"] = false
            }

            if let properties = object["properties"] as? [String: Any] {
                object["properties"] = properties.mapValues {
                    normalizedPlanningInputSchema($0)
                }
            }

            if let items = object["items"] {
                object["items"] = normalizedPlanningInputSchema(items)
            }

            for key in ["anyOf", "oneOf", "allOf", "prefixItems"] {
                if let values = object[key] as? [Any] {
                    object[key] = values.map { normalizedPlanningInputSchema($0) }
                }
            }

            for key in ["$defs", "definitions"] {
                if let values = object[key] as? [String: Any] {
                    object[key] = values.mapValues { normalizedPlanningInputSchema($0) }
                }
            }

            return object
        }

        if let array = value as? [Any] {
            return array.map { normalizedPlanningInputSchema($0) }
        }

        return value
    }
}

/// Tool registry that derives its catalog from the Rust `omega-mcp` crate.
/// `builtinToolsJson()` is the single source of truth; this enum is a decoded Swift cache.
nonisolated enum OmegaToolRegistry {
    private static let agentHeaders: [String: String] = [
        "safari": "SAFARI agent:",
        "file": "FILE agent (vault-scoped):",
        "notes": "NOTES agent (Epistemos knowledge base):",
        "terminal": "TERMINAL agent:",
        "automation": "AUTOMATION agent (macOS UI):",
    ]

    private static let agentOrder = ["safari", "file", "notes", "terminal", "automation"]

    /// Lazily decoded tool catalog from the Rust `builtinToolsJson()` export.
    /// Falls back to an empty array if the Rust catalog is unavailable or malformed.
    static let all: [OmegaToolDefinition] = {
        let json = builtinToolsJson()
        guard let data = json.data(using: .utf8),
              let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }
        return array.compactMap { dict -> OmegaToolDefinition? in
            guard let name = dict["name"] as? String,
                  let description = dict["description"] as? String else { return nil }
            let agent = dict["agent"] as? String ?? ""
            let schemaJson = dict["input_schema_json"] as? String ?? "{}"
            let example = dict["arguments_example"] as? String ?? "{}"
            let safety = dict["safety"] as? [String: Any]
            let destructive = safety?["destructive"] as? Bool ?? false
            let requiresConfirmation = safety?["requires_confirmation"] as? Bool ?? false
            return OmegaToolDefinition(
                name: name,
                agent: agent,
                description: description,
                argumentsExample: example,
                schemaJson: schemaJson,
                destructive: destructive,
                requiresConfirmation: requiresConfirmation
            )
        }
    }()

    static var planningSchemas: [[String: Any]] {
        planningSchemas(distribution: .currentBuild)
    }

    static func planningSchemas(
        distribution: ToolSurfacePolicy.Distribution
    ) -> [[String: Any]] {
        surfacedTools(distribution: distribution).map(\.planningSchema)
    }

    static var planningSchemasJson: String {
        planningSchemasJson(distribution: .currentBuild)
    }

    static func planningSchemasJson(
        distribution: ToolSurfacePolicy.Distribution
    ) -> String {
        (try? JSONSerialization.data(
            withJSONObject: planningSchemas(distribution: distribution),
            options: [.sortedKeys]
        ))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
    }

    static var catalogJson: String {
        catalogJson(distribution: .currentBuild)
    }

    static func catalogJson(
        distribution: ToolSurfacePolicy.Distribution
    ) -> String {
        let json = builtinToolsJson()
        guard let data = json.data(using: .utf8),
              let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return "[]"
        }
        let filtered = array.filter { dict in
            guard let name = dict["name"] as? String else { return false }
            return ToolSurfacePolicy.isSurfacedToolName(name, distribution: distribution)
        }
        return (try? JSONSerialization.data(
            withJSONObject: filtered,
            options: [.sortedKeys]
        ))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
    }

    static func surfacedTools(
        distribution: ToolSurfacePolicy.Distribution = .currentBuild
    ) -> [OmegaToolDefinition] {
        ToolSurfacePolicy.surfacedTools(all, distribution: distribution)
    }

    static func agent(for toolName: String) -> String? {
        all.first(where: { $0.name == toolName })?.agent
    }

    static func planningPromptBlock(
        distribution: ToolSurfacePolicy.Distribution = .currentBuild
    ) -> String {
        var lines: [String] = []
        let surfacedTools = surfacedTools(distribution: distribution)

        for agent in agentOrder {
            guard let header = agentHeaders[agent] else { continue }
            let tools = surfacedTools.filter { $0.agent == agent }
            guard !tools.isEmpty else { continue }

            if !lines.isEmpty {
                lines.append("")
            }

            lines.append(header)
            for tool in tools {
                lines.append("- \(tool.name): \(tool.description). Args: \(tool.argumentsExample)")
            }
        }

        return lines.joined(separator: "\n")
    }
}

// MARK: - MCP Bridge

/// Swift-side bridge to the Rust omega-mcp MCPDispatcher.
/// Creates the dispatcher, registers all agent tools, and provides
/// logging + query access for the UI.
@MainActor @Observable
final class MCPBridge {

    /// The Rust-side dispatcher (UniFFI object).
    /// Nil if the database path couldn't be resolved.
    private(set) var dispatcher: McpDispatcher?

    /// Number of registered tools.
    var toolCount: Int {
        Int(dispatcher?.toolCount() ?? 0)
    }

    /// Total logged executions.
    var executionCount: Int {
        Int(dispatcher?.executionCount() ?? 0)
    }

    init() {
        // Create the SQLite database in Application Support
        let dbPath = Self.executionLogPath()
        dispatcher = McpDispatcher(logDbPath: dbPath)
        // Register all built-in tools from the Rust catalog (single source of truth).
        // This replaces the previous Swift-side registerAllTools() loop.
        _ = dispatcher?.registerBuiltinTools()
    }

    // MARK: - Agent Command Center

    /// Tools grouped by agent for the Command Center inspector.
    var toolsByAgent: [String: [OmegaToolDefinition]] {
        Dictionary(grouping: OmegaToolRegistry.all, by: \.agent)
    }

    // MARK: - Catalog Query

    /// Returns the distribution-visible tool catalog decoded from the Rust source of truth.
    static func builtinCatalogJson(
        distribution: ToolSurfacePolicy.Distribution = .currentBuild
    ) -> String {
        OmegaToolRegistry.catalogJson(distribution: distribution)
    }

    // MARK: - Execution Logging

    /// Log a tool execution result.
    func logExecution(toolName: String, argumentsJson: String, resultJson: String, durationMs: UInt64, success: Bool) {
        _ = dispatcher?.logExecution(
            id: UUID().uuidString,
            timestamp: ISO8601DateFormatter().string(from: Date()),
            toolName: toolName,
            argumentsJson: argumentsJson,
            resultJson: resultJson,
            durationMs: durationMs,
            success: success
        )
    }

    /// Query recent executions as JSON.
    func recentExecutionsJson(limit: Int = 20) -> String {
        dispatcher?.recentExecutionsJson(limit: UInt32(limit)) ?? "[]"
    }

    // MARK: - Dispatch

    /// Dispatch a JSON-RPC request and return the response.
    func dispatch(
        _ requestJson: String,
        distribution: ToolSurfacePolicy.Distribution = .currentBuild
    ) -> String {
        if let gateResponse = Self.policyGateResponse(
            for: requestJson,
            distribution: distribution
        ) {
            return gateResponse
        }
        return dispatcher?.dispatch(requestJson: requestJson) ?? "{\"error\":\"Dispatcher not initialized\"}"
    }

    private static func policyGateResponse(
        for requestJson: String,
        distribution: ToolSurfacePolicy.Distribution
    ) -> String? {
        guard let data = requestJson.data(using: .utf8),
              let request = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let method = request["method"] as? String else {
            return nil
        }

        let id = request["id"] ?? NSNull()
        switch method {
        case "tools/list":
            let resolvedDistribution = ToolSurfacePolicy.resolvedDistribution(
                distribution
            )
            let visibleTools = OmegaToolRegistry.surfacedTools(
                distribution: distribution
            )
            let visibleNames = Set(visibleTools.map(\.name))
            let allNames = Set(OmegaToolRegistry.all.map(\.name))
            guard resolvedDistribution != .proResearch || visibleNames != allNames else {
                return nil
            }
            return jsonRpcSuccess(
                id: id,
                result: [
                    "tools": visibleTools.map(\.planningSchema),
                ]
            )
        case "tools/call":
            guard let params = request["params"] as? [String: Any],
                  let toolName = params["name"] as? String else {
                return nil
            }
            guard ToolSurfacePolicy.isSurfacedToolName(
                toolName,
                distribution: distribution
            ) else {
                return jsonRpcError(
                    id: id,
                    code: -32601,
                    message: "Tool not found: \(toolName)"
                )
            }
            return nil
        default:
            return nil
        }
    }

    private static func jsonRpcSuccess(id: Any, result: [String: Any]) -> String {
        serializeJsonRpc([
            "jsonrpc": "2.0",
            "result": result,
            "id": id,
        ])
    }

    private static func jsonRpcError(id: Any, code: Int, message: String) -> String {
        serializeJsonRpc([
            "jsonrpc": "2.0",
            "error": [
                "code": code,
                "message": message,
            ],
            "id": id,
        ])
    }

    private static func serializeJsonRpc(_ response: [String: Any]) -> String {
        (try? JSONSerialization.data(withJSONObject: response, options: [.sortedKeys]))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "{\"jsonrpc\":\"2.0\",\"error\":{\"code\":-32603,\"message\":\"Internal error\"},\"id\":null}"
    }

    // MARK: - Paths

    private static func executionLogPath() -> String {
        let support = FoundationSafety.userApplicationSupportDirectory()
        let dir = support.appendingPathComponent("Epistemos", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("omega_executions.db").path
    }
}
