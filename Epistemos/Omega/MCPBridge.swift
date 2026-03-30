import Foundation

nonisolated struct OmegaToolDefinition {
    let name: String
    let agent: String
    let description: String
    let argumentsExample: String
    let schemaJson: String
    let destructive: Bool
    let requiresConfirmation: Bool

    fileprivate var planningSchema: [String: Any] {
        var schema: [String: Any] = [
            "name": name,
            "description": description,
        ]
        if let data = schemaJson.data(using: .utf8),
           let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            schema["inputSchema"] = parsed
        }
        return schema
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
        all.map(\.planningSchema)
    }

    static let planningSchemasJson: String = {
        (try? JSONSerialization.data(withJSONObject: planningSchemas, options: [.sortedKeys]))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
    }()

    static func agent(for toolName: String) -> String? {
        all.first(where: { $0.name == toolName })?.agent
    }

    static func planningPromptBlock() -> String {
        var lines: [String] = []

        for agent in agentOrder {
            guard let header = agentHeaders[agent] else { continue }
            let tools = all.filter { $0.agent == agent }
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

    // MARK: - Catalog Query

    /// Returns the built-in tool catalog from Rust as a JSON array.
    /// This is the single source of truth for tool definitions.
    static func builtinCatalogJson() -> String {
        builtinToolsJson()
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
    func dispatch(_ requestJson: String) -> String {
        dispatcher?.dispatch(requestJson: requestJson) ?? "{\"error\":\"Dispatcher not initialized\"}"
    }

    // MARK: - Paths

    private static func executionLogPath() -> String {
        let support = FoundationSafety.userApplicationSupportDirectory()
        let dir = support.appendingPathComponent("Epistemos", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("omega_executions.db").path
    }
}
