import Foundation

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

        // Safari Agent tools
        register(d, name: "open_url", description: "Open a URL in Safari",
                 schema: #"{"type":"object","properties":{"url":{"type":"string"}},"required":["url"]}"#)
        register(d, name: "get_page_url", description: "Get the URL of Safari's current tab",
                 schema: #"{"type":"object","properties":{}}"#)
        register(d, name: "get_page_title", description: "Get the title of Safari's current tab",
                 schema: #"{"type":"object","properties":{}}"#)
        register(d, name: "search_web", description: "Search the web via Google in Safari",
                 schema: #"{"type":"object","properties":{"query":{"type":"string"}},"required":["query"]}"#)

        // File Agent tools
        register(d, name: "read_file", description: "Read a file from the vault",
                 schema: #"{"type":"object","properties":{"path":{"type":"string"}},"required":["path"]}"#)
        register(d, name: "write_file", description: "Write content to a file in the vault",
                 schema: #"{"type":"object","properties":{"path":{"type":"string"},"content":{"type":"string"}},"required":["path","content"]}"#)
        register(d, name: "list_files", description: "List files in a vault directory",
                 schema: #"{"type":"object","properties":{"path":{"type":"string"}},"required":["path"]}"#)
        register(d, name: "move_file", description: "Move a file within the vault",
                 schema: #"{"type":"object","properties":{"path":{"type":"string"},"destination":{"type":"string"}},"required":["path","destination"]}"#)
        register(d, name: "delete_file", description: "Delete a file from the vault",
                 schema: #"{"type":"object","properties":{"path":{"type":"string"}},"required":["path"]}"#,
                 destructive: true, requiresConfirmation: true)

        // Notes Agent tools
        register(d, name: "create_note", description: "Create a new Epistemos note",
                 schema: #"{"type":"object","properties":{"title":{"type":"string"},"body":{"type":"string"}},"required":["title"]}"#)
        register(d, name: "edit_note", description: "Edit an existing note",
                 schema: #"{"type":"object","properties":{"id":{"type":"string"},"body":{"type":"string"}},"required":["id"]}"#)
        register(d, name: "search_notes", description: "Search notes by content",
                 schema: #"{"type":"object","properties":{"query":{"type":"string"}},"required":["query"]}"#)
        register(d, name: "list_notes", description: "List all notes",
                 schema: #"{"type":"object","properties":{}}"#)

        // Terminal Agent tools
        register(d, name: "run_command", description: "Execute a shell command (allow-listed only)",
                 schema: #"{"type":"object","properties":{"command":{"type":"string"}},"required":["command"]}"#)

        // Automation Agent tools
        register(d, name: "get_ui_tree", description: "Get the accessibility tree for an app by PID",
                 schema: #"{"type":"object","properties":{"pid":{"type":"integer"}},"required":["pid"]}"#)
        register(d, name: "click_element", description: "Click at screen coordinates",
                 schema: #"{"type":"object","properties":{"x":{"type":"number"},"y":{"type":"number"}},"required":["x","y"]}"#)
        register(d, name: "type_text", description: "Type text via simulated keyboard input",
                 schema: #"{"type":"object","properties":{"text":{"type":"string"}},"required":["text"]}"#)
        register(d, name: "run_shortcut", description: "Execute a named macOS Shortcut",
                 schema: #"{"type":"object","properties":{"name":{"type":"string"}},"required":["name"]}"#)
    }

    private func register(_ d: McpDispatcher, name: String, description: String,
                          schema: String, destructive: Bool = false, requiresConfirmation: Bool = false) {
        let err = d.registerTool(
            name: name, description: description, inputSchemaJson: schema,
            destructive: destructive, requiresConfirmation: requiresConfirmation
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
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = support.appendingPathComponent("Epistemos", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("omega_executions.db").path
    }
}
