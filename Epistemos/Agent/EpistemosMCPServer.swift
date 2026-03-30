import Foundation
import os

// MARK: - Epistemos MCP Server
// Receives JSON-RPC requests from the Hermes subprocess and dispatches
// to registered macOS tool handlers. Sends responses back via stdin pipe.
// Mirrors the Rust StdioServer in omega-mcp/src/transport.rs.

private let mcpServerLog = Logger(subsystem: "com.epistemos", category: "EpistemosMCPServer")

// MARK: - Types

/// An incoming MCP request parsed from JSON-RPC.
struct MCPIncomingRequest: Sendable {
    let method: String
    let params: AnyCodableValue
    let id: AnyCodableValue?
}

/// Result of handling an MCP tool call.
enum MCPToolResult: Sendable {
    case success(AnyCodableValue)
    case error(code: Int, message: String)
}

/// Handler closure for an MCP method.
typealias MCPMethodHandler = @Sendable (AnyCodableValue) async -> MCPToolResult

// MARK: - MCP Server

final class EpistemosMCPServer: @unchecked Sendable {
    private let lock = NSLock()
    private nonisolated(unsafe) var handlers: [String: MCPMethodHandler] = [:]
    private nonisolated(unsafe) weak var subprocessManager: HermesSubprocessManager?
    private nonisolated(unsafe) var readerTask: Task<Void, Never>?

    /// Tools exposed to Hermes via tools/list.
    private nonisolated(unsafe) var registeredTools: [[String: AnyCodableValue]] = []

    init(subprocessManager: HermesSubprocessManager) {
        self.subprocessManager = subprocessManager
        registerBuiltinHandlers()
    }

    // MARK: - Handler Registration

    /// Register a handler for an MCP method (e.g. "tools/call").
    func registerHandler(method: String, handler: @escaping MCPMethodHandler) {
        lock.lock()
        defer { lock.unlock() }
        handlers[method] = handler
    }

    /// Register a tool that will appear in tools/list and be callable via tools/call.
    func registerTool(
        name: String,
        description: String,
        inputSchema: [String: AnyCodableValue],
        handler: @escaping MCPMethodHandler
    ) {
        let toolDef: [String: AnyCodableValue] = [
            "name": .string(name),
            "description": .string(description),
            "inputSchema": .dictionary(inputSchema),
        ]

        lock.lock()
        registeredTools.append(toolDef)
        lock.unlock()

        // Register a dispatch handler that routes tools/call to the right tool
        // (done once in registerBuiltinHandlers via the tools/call handler)
        mcpServerLog.info("Registered MCP tool: \(name)")
    }

    // MARK: - Request Handling

    /// Process a single incoming JSON-RPC line.
    /// Called from the stdout reader or externally.
    func handleRequestLine(_ jsonLine: String) {
        guard let data = jsonLine.data(using: .utf8),
              let parsed = try? JSONDecoder().decode(IncomingJsonRpc.self, from: data) else {
            mcpServerLog.warning("Failed to parse incoming MCP request: \(jsonLine.prefix(200))")
            return
        }

        // Skip if it looks like a response (has result or error field)
        if parsed.result != nil || parsed.error != nil {
            return // This is a response, not a request — let MCP client handle it
        }

        guard let method = parsed.method else {
            mcpServerLog.warning("MCP request missing method field")
            return
        }

        let request = MCPIncomingRequest(
            method: method,
            params: parsed.params ?? .null,
            id: parsed.id
        )

        Task {
            await dispatchRequest(request)
        }
    }

    private nonisolated func lookupHandler(method: String) -> MCPMethodHandler? {
        lock.lock()
        defer { lock.unlock() }
        return handlers[method]
    }

    private nonisolated func lookupRegisteredTools() -> [[String: AnyCodableValue]] {
        lock.lock()
        defer { lock.unlock() }
        return registeredTools
    }

    private func dispatchRequest(_ request: MCPIncomingRequest) async {
        let handler = lookupHandler(method: request.method)

        guard let handler else {
            mcpServerLog.debug("No handler for MCP method: \(request.method)")
            if let id = request.id {
                sendErrorResponse(code: -32601, message: "Method not found: \(request.method)", id: id)
            }
            return
        }

        let result = await handler(request.params)

        // Only send response if request has an ID (not a notification)
        guard let id = request.id else { return }

        switch result {
        case .success(let value):
            sendSuccessResponse(result: value, id: id)
        case .error(let code, let message):
            sendErrorResponse(code: code, message: message, id: id)
        }
    }

    // MARK: - Response Sending

    private func sendSuccessResponse(result: AnyCodableValue, id: AnyCodableValue) {
        let response: [String: AnyCodableValue] = [
            "jsonrpc": .string("2.0"),
            "result": result,
            "id": id,
        ]
        sendResponse(response)
    }

    private func sendErrorResponse(code: Int, message: String, id: AnyCodableValue) {
        let response: [String: AnyCodableValue] = [
            "jsonrpc": .string("2.0"),
            "error": .dictionary([
                "code": .int(code),
                "message": .string(message),
            ]),
            "id": id,
        ]
        sendResponse(response)
    }

    private func sendResponse(_ response: [String: AnyCodableValue]) {
        guard let data = try? JSONEncoder().encode(response),
              let json = String(data: data, encoding: .utf8) else {
            mcpServerLog.error("Failed to encode MCP response")
            return
        }

        do {
            try subprocessManager?.writeLine(json)
        } catch {
            mcpServerLog.error("Failed to send MCP response: \(error.localizedDescription)")
        }
    }

    // MARK: - Builtin Handlers

    private func registerBuiltinHandlers() {
        // Initialize protocol
        registerHandler(method: "initialize") { _ in
            return .success(.dictionary([
                "protocolVersion": .string("2024-11-05"),
                "capabilities": .dictionary([
                    "tools": .dictionary([:]),
                ]),
                "serverInfo": .dictionary([
                    "name": .string("epistemos"),
                    "version": .string("1.0.0"),
                ]),
            ]))
        }

        // Ping
        registerHandler(method: "ping") { _ in
            .success(.dictionary([:]))
        }

        // List tools
        registerHandler(method: "tools/list") { [weak self] _ in
            guard let self else { return .error(code: -32603, message: "Server deallocated") }
            let tools = self.lookupRegisteredTools()
            return .success(.dictionary([
                "tools": .array(tools.map { .dictionary($0) }),
            ]))
        }

        // Call tool
        registerHandler(method: "tools/call") { [weak self] params in
            guard let self else { return .error(code: -32603, message: "Server deallocated") }

            // Extract tool name from params
            guard case .dictionary(let dict) = params,
                  case .string(let toolName) = dict["name"] else {
                return .error(code: -32602, message: "Missing 'name' in tools/call params")
            }

            let arguments = dict["arguments"] ?? .dictionary([:])

            // Find tool-specific handler via sync lookup
            let toolKey = "tool:\(toolName)"
            let handler = self.lookupHandler(method: toolKey)

            guard let handler else {
                return .error(code: -32602, message: "Unknown tool: \(toolName)")
            }

            return await handler(arguments)
        }
    }

    /// Register a tool handler (called via tools/call dispatch).
    func registerToolHandler(name: String, handler: @escaping MCPMethodHandler) {
        lock.lock()
        defer { lock.unlock() }
        handlers["tool:\(name)"] = handler
    }
}

// MARK: - Internal JSON-RPC Parsing

/// Flexible parser for incoming JSON-RPC messages that might be
/// either requests or responses.
private struct IncomingJsonRpc: Decodable {
    let jsonrpc: String?
    let method: String?
    let params: AnyCodableValue?
    let id: AnyCodableValue?
    let result: AnyCodableValue?
    let error: AnyCodableValue?
}
