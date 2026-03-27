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

nonisolated enum OmegaToolRegistry {
    private static let agentHeaders: [String: String] = [
        "safari": "SAFARI agent:",
        "file": "FILE agent (vault-scoped):",
        "notes": "NOTES agent (Epistemos knowledge base):",
        "terminal": "TERMINAL agent:",
        "automation": "AUTOMATION agent (macOS UI):",
    ]

    private static let agentOrder = ["safari", "file", "notes", "terminal", "automation"]

    static let all: [OmegaToolDefinition] = [
        OmegaToolDefinition(name: "open_url", agent: "safari", description: "Open a URL in Safari", argumentsExample: #"{"url": "https://..."}"#, schemaJson: #"{"type":"object","properties":{"url":{"type":"string"}},"required":["url"]}"#, destructive: false, requiresConfirmation: false),
        OmegaToolDefinition(name: "get_page_url", agent: "safari", description: "Get the URL of Safari's current tab", argumentsExample: #"{}"#, schemaJson: #"{"type":"object","properties":{}}"#, destructive: false, requiresConfirmation: false),
        OmegaToolDefinition(name: "get_page_title", agent: "safari", description: "Get the title of Safari's current tab", argumentsExample: #"{}"#, schemaJson: #"{"type":"object","properties":{}}"#, destructive: false, requiresConfirmation: false),
        OmegaToolDefinition(name: "search_web", agent: "safari", description: "Search the web via Google in Safari", argumentsExample: #"{"query": "search terms"}"#, schemaJson: #"{"type":"object","properties":{"query":{"type":"string"}},"required":["query"]}"#, destructive: false, requiresConfirmation: false),
        OmegaToolDefinition(name: "read_file", agent: "file", description: "Read a file from the vault", argumentsExample: #"{"path": "relative/path.md"}"#, schemaJson: #"{"type":"object","properties":{"path":{"type":"string"}},"required":["path"]}"#, destructive: false, requiresConfirmation: false),
        OmegaToolDefinition(name: "write_file", agent: "file", description: "Write content to a file in the vault", argumentsExample: #"{"path": "relative/path.md", "content": "..."}"#, schemaJson: #"{"type":"object","properties":{"path":{"type":"string"},"content":{"type":"string"}},"required":["path","content"]}"#, destructive: false, requiresConfirmation: false),
        OmegaToolDefinition(name: "list_files", agent: "file", description: "List files in a vault directory", argumentsExample: #"{"path": "."}"#, schemaJson: #"{"type":"object","properties":{"path":{"type":"string"}},"required":["path"]}"#, destructive: false, requiresConfirmation: false),
        OmegaToolDefinition(name: "move_file", agent: "file", description: "Move a file within the vault", argumentsExample: #"{"path": "old.md", "destination": "new.md"}"#, schemaJson: #"{"type":"object","properties":{"path":{"type":"string"},"destination":{"type":"string"}},"required":["path","destination"]}"#, destructive: false, requiresConfirmation: false),
        OmegaToolDefinition(name: "delete_file", agent: "file", description: "Delete a file from the vault", argumentsExample: #"{"path": "relative/path.md"}"#, schemaJson: #"{"type":"object","properties":{"path":{"type":"string"}},"required":["path"]}"#, destructive: true, requiresConfirmation: true),
        OmegaToolDefinition(name: "create_note", agent: "notes", description: "Create a new Epistemos note", argumentsExample: #"{"title": "...", "body": "..."}"#, schemaJson: #"{"type":"object","properties":{"title":{"type":"string"},"body":{"type":"string"}},"required":["title"]}"#, destructive: false, requiresConfirmation: false),
        OmegaToolDefinition(name: "edit_note", agent: "notes", description: "Edit an existing note", argumentsExample: #"{"id": "page-uuid", "body": "new content"}"#, schemaJson: #"{"type":"object","properties":{"id":{"type":"string"},"body":{"type":"string"}},"required":["id"]}"#, destructive: false, requiresConfirmation: false),
        OmegaToolDefinition(name: "search_notes", agent: "notes", description: "Search notes by content", argumentsExample: #"{"query": "search terms"}"#, schemaJson: #"{"type":"object","properties":{"query":{"type":"string"}},"required":["query"]}"#, destructive: false, requiresConfirmation: false),
        OmegaToolDefinition(name: "list_notes", agent: "notes", description: "List all notes", argumentsExample: #"{}"#, schemaJson: #"{"type":"object","properties":{}}"#, destructive: false, requiresConfirmation: false),
        OmegaToolDefinition(name: "run_command", agent: "terminal", description: "Execute a shell command (allow-listed only)", argumentsExample: #"{"command": "ls -la"}"#, schemaJson: #"{"type":"object","properties":{"command":{"type":"string"}},"required":["command"]}"#, destructive: false, requiresConfirmation: false),
        OmegaToolDefinition(name: "get_ui_tree", agent: "automation", description: "Get the accessibility tree for an app by name or PID", argumentsExample: #"{"app": "AppName"} or {"pid": 1234}"#, schemaJson: #"{"type":"object","properties":{"app":{"type":"string","description":"App name (case-insensitive)"},"pid":{"type":"integer","description":"Process ID"}}}"#, destructive: false, requiresConfirmation: false),
        OmegaToolDefinition(name: "click_element", agent: "automation", description: "Click a UI element by name or screen coordinates", argumentsExample: #"{"app": "AppName", "element": "Button Name"} or {"x": 500, "y": 300}"#, schemaJson: #"{"type":"object","properties":{"app":{"type":"string","description":"App name for semantic click"},"pid":{"type":"integer","description":"Process ID for semantic click"},"element":{"type":"string","description":"Element name to click"},"x":{"type":"number","description":"Screen X coordinate"},"y":{"type":"number","description":"Screen Y coordinate"}}}"#, destructive: false, requiresConfirmation: false),
        OmegaToolDefinition(name: "type_text", agent: "automation", description: "Type text via simulated keyboard input", argumentsExample: #"{"text": "..."}"#, schemaJson: #"{"type":"object","properties":{"text":{"type":"string"}},"required":["text"]}"#, destructive: false, requiresConfirmation: false),
        OmegaToolDefinition(name: "press_key", agent: "automation", description: "Press a key with optional modifiers", argumentsExample: #"{"key_code": 36, "modifiers": 0}"#, schemaJson: #"{"type":"object","properties":{"key_code":{"type":"integer","description":"macOS virtual key code (e.g. 36=Return, 49=Space)"},"modifiers":{"type":"integer","description":"CGEventFlags bitmask (e.g. 256=Shift, 1048576=Cmd)"}},"required":["key_code"]}"#, destructive: false, requiresConfirmation: false),
        OmegaToolDefinition(name: "run_shortcut", agent: "automation", description: "Execute a named macOS Shortcut", argumentsExample: #"{"name": "shortcut-name"}"#, schemaJson: #"{"type":"object","properties":{"name":{"type":"string"}},"required":["name"]}"#, destructive: false, requiresConfirmation: false),
    ]

    static var planningSchemas: [[String: Any]] {
        all.map(\.planningSchema)
    }

    static var planningSchemasJson: String {
        (try? JSONSerialization.data(withJSONObject: planningSchemas, options: [.sortedKeys]))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
    }

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
        registerAllTools()
    }

    // MARK: - Tool Registration

    /// Register all tools from all specialist agents.
    private func registerAllTools() {
        guard let d = dispatcher else { return }
        for tool in OmegaToolRegistry.all {
            register(d, tool: tool)
        }
    }

    private func register(_ d: McpDispatcher, tool: OmegaToolDefinition) {
        let err = d.registerTool(
            name: tool.name,
            description: tool.description,
            inputSchemaJson: tool.schemaJson,
            destructive: tool.destructive,
            requiresConfirmation: tool.requiresConfirmation
        )
        if !err.isEmpty {
            // Tool already registered or invalid schema — log but don't crash
        }
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
