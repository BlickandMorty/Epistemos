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
            "name": AgentToolNameAliases.canonical(name),
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
        "browser": "BROWSER tools (MAS in-app web):",
    ]

    private static let agentOrder = ["safari", "browser", "file", "notes", "terminal", "automation"]

    /// Lazily decoded tool catalog from the Rust `builtinToolsJson()` export.
    /// Falls back to an empty array if the Rust catalog is unavailable or malformed.
    static let all: [OmegaToolDefinition] = {
        decodedBuiltinTools().map { tool in
            OmegaToolDefinition(
                name: AgentToolNameAliases.canonical(tool.name),
                agent: tool.agent,
                description: tool.description,
                argumentsExample: tool.argumentsExample,
                schemaJson: tool.schemaJson,
                destructive: tool.destructive,
                requiresConfirmation: tool.requiresConfirmation
            )
        }
    }()

    private static let registeredNameByCanonicalName: [String: String] = {
        var names: [String: String] = [:]
        for tool in decodedBuiltinTools() {
            names[AgentToolNameAliases.canonical(tool.name)] = tool.name
        }
        return names
    }()

    private static func decodedBuiltinTools() -> [OmegaToolDefinition] {
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
    }

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
        var seenCanonicalNames: Set<String> = []
        let filtered = array.compactMap { dict -> [String: Any]? in
            guard let name = dict["name"] as? String else { return nil }
            let canonicalName = AgentToolNameAliases.canonical(name)
            guard ToolSurfacePolicy.isSurfacedToolName(canonicalName, distribution: distribution),
                  seenCanonicalNames.insert(canonicalName).inserted else {
                return nil
            }
            var canonicalized = dict
            canonicalized["name"] = canonicalName
            return canonicalized
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
        let canonicalName = AgentToolNameAliases.canonical(toolName)
        return all.first {
            AgentToolNameAliases.canonical($0.name) == canonicalName
        }?.agent
    }

    static func registeredName(for toolName: String) -> String? {
        let canonicalName = AgentToolNameAliases.canonical(toolName)
        if let registeredName = registeredNameByCanonicalName[canonicalName] {
            return registeredName
        }
        return all.contains { $0.name == canonicalName } ? canonicalName : nil
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
                lines.append("- \(AgentToolNameAliases.canonical(tool.name)): \(tool.description). Args: \(tool.argumentsExample)")
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
    private static let maxDispatchRequestBytes = 1024 * 1024
    private static let maxJSONRPCIDStringCharacters = 128
    private static let maxPolicyGateToolNameCharacters = 128

    /// The Rust-side dispatcher (UniFFI object).
    /// Nil if the database path couldn't be resolved.
    private(set) var dispatcher: McpDispatcher?
    @ObservationIgnored
    private let agentProvenanceRecorder: AgentToolProvenanceRecorder
    @ObservationIgnored
    private var policyGateToolCallSequence: UInt64 = 0

    /// Number of registered tools.
    var toolCount: Int {
        Int(dispatcher?.toolCount() ?? 0)
    }

    /// Total logged executions.
    var executionCount: Int {
        Int(dispatcher?.executionCount() ?? 0)
    }

    init(
        agentProvenanceRecorder: AgentToolProvenanceRecorder = AgentToolProvenanceRecorder()
    ) {
        self.agentProvenanceRecorder = agentProvenanceRecorder
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
        Dictionary(grouping: OmegaToolRegistry.surfacedTools(), by: \.agent)
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
        guard requestJson.utf8.count <= Self.maxDispatchRequestBytes else {
            return Self.jsonRpcError(
                id: NSNull(),
                code: -32600,
                message: "MCP request exceeds maximum size."
            )
        }
        if let gateResponse = policyGateResponse(
            for: requestJson,
            distribution: distribution
        ) {
            return gateResponse
        }
        let dispatchJSON = Self.rustCatalogCompatibleRequestJson(requestJson)
        let responseJSON = dispatcher?.dispatch(requestJson: dispatchJSON) ?? "{\"error\":\"Dispatcher not initialized\"}"
        return Self.canonicalizedToolCallResponseJson(responseJSON)
    }

    private func policyGateResponse(
        for requestJson: String,
        distribution: ToolSurfacePolicy.Distribution
    ) -> String? {
        guard let data = requestJson.data(using: .utf8),
              let request = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let method = request["method"] as? String else {
            return nil
        }

        let id = Self.jsonRpcResponseID(from: request["id"])
        switch method {
        case "tools/list":
            let visibleTools = OmegaToolRegistry.surfacedTools(
                distribution: distribution
            )
            return Self.jsonRpcSuccess(
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
                let safeToolName = Self.boundedPolicyGateToolName(toolName)
                recordToolCallPolicyDenial(
                    toolName: safeToolName,
                    distribution: distribution
                )
                return Self.jsonRpcError(
                    id: id,
                    code: -32601,
                    message: "Tool not found: \(safeToolName)"
                )
            }
            return nil
        default:
            return nil
        }
    }

    private nonisolated static func rustCatalogCompatibleRequestJson(_ requestJson: String) -> String {
        guard let data = requestJson.data(using: .utf8),
              var request = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              request["method"] as? String == "tools/call",
              var params = request["params"] as? [String: Any],
              let toolName = params["name"] as? String,
              let registeredName = OmegaToolRegistry.registeredName(for: toolName),
              registeredName != toolName else {
            return requestJson
        }

        params["name"] = registeredName
        request["params"] = params

        guard let encoded = try? JSONSerialization.data(withJSONObject: request, options: [.sortedKeys]),
              let string = String(data: encoded, encoding: .utf8) else {
            return requestJson
        }
        return string
    }

    private nonisolated static func canonicalizedToolCallResponseJson(_ responseJson: String) -> String {
        guard let data = responseJson.data(using: .utf8),
              var response = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              var result = response["result"] as? [String: Any],
              let toolName = result["tool_name"] as? String else {
            return responseJson
        }

        let canonicalName = AgentToolNameAliases.canonical(toolName)
        guard canonicalName != toolName else { return responseJson }
        result["tool_name"] = canonicalName
        response["result"] = result

        guard let encoded = try? JSONSerialization.data(withJSONObject: response, options: [.sortedKeys]),
              let string = String(data: encoded, encoding: .utf8) else {
            return responseJson
        }
        return string
    }

    private func recordToolCallPolicyDenial(
        toolName: String,
        distribution: ToolSurfacePolicy.Distribution
    ) {
        let toolCallID = nextPolicyGateToolCallID()
        let resolvedDistribution = ToolSurfacePolicy.resolvedDistribution(distribution)
        let metadata = [
            "source": "mcp_bridge_policy_gate",
            "surface": "omega_dispatch",
            "method": "tools/call",
            "distribution": Self.policyGateDistributionName(resolvedDistribution),
            "policy": "tool_surface",
        ]
        let argumentsJSON = #"{"method":"tools/call","policy_gate":"tool_surface"}"#

        _ = agentProvenanceRecorder.recordToolEvent(
            runID: "mcp-bridge-policy-gate",
            traceID: nil,
            kind: .toolCallRequested,
            actor: .system,
            toolCallID: toolCallID,
            toolName: toolName,
            argumentsJSON: argumentsJSON,
            status: .requested,
            metadata: metadata
        )
        _ = agentProvenanceRecorder.recordToolEvent(
            runID: "mcp-bridge-policy-gate",
            traceID: nil,
            kind: .toolCallDenied,
            actor: .system,
            toolCallID: toolCallID,
            toolName: toolName,
            argumentsJSON: argumentsJSON,
            status: .denied,
            errorMessage: "Tool is not surfaced for this distribution.",
            metadata: metadata
        )
    }

    private func nextPolicyGateToolCallID() -> String {
        let sequence = policyGateToolCallSequence
        if policyGateToolCallSequence < UInt64.max {
            policyGateToolCallSequence += 1
        }
        return "mcp-policy-denial-\(sequence)"
    }

    private static func policyGateDistributionName(
        _ distribution: ToolSurfacePolicy.Distribution
    ) -> String {
        switch distribution {
        case .currentBuild:
            "current_build"
        case .coreAppStore:
            "core_app_store"
        case .proResearch:
            "pro_research"
        }
    }

    private static func jsonRpcResponseID(from rawID: Any?) -> Any {
        guard let rawID else { return NSNull() }
        if rawID is NSNull {
            return NSNull()
        }
        if let id = rawID as? String {
            return boundedJSONRPCIDString(id)
        }
        if let id = rawID as? NSNumber {
            guard String(cString: id.objCType) != "c" else { return NSNull() }
            return id
        }
        return NSNull()
    }

    private static func boundedJSONRPCIDString(_ value: String) -> String {
        let bounded = String(value.prefix(maxJSONRPCIDStringCharacters + 32))
        guard bounded.count > maxJSONRPCIDStringCharacters else {
            return bounded
        }
        return String(bounded.prefix(maxJSONRPCIDStringCharacters - 3)) + "..."
    }

    private static func boundedPolicyGateToolName(_ value: String) -> String {
        let bounded = String(value.prefix(maxPolicyGateToolNameCharacters + 32))
        let trimmed = bounded.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return "<unnamed>"
        }
        guard trimmed.unicodeScalars.allSatisfy(isPolicyGateToolNameScalar) else {
            return "<invalid>"
        }
        guard trimmed.count > maxPolicyGateToolNameCharacters else {
            return trimmed
        }
        return String(trimmed.prefix(maxPolicyGateToolNameCharacters - 3)) + "..."
    }

    private static func isPolicyGateToolNameScalar(_ scalar: Unicode.Scalar) -> Bool {
        scalar == "."
            || scalar == "_"
            || scalar == "-"
            || (65...90).contains(Int(scalar.value))
            || (97...122).contains(Int(scalar.value))
            || (48...57).contains(Int(scalar.value))
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
