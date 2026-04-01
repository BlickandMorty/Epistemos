import Foundation
import os

// MARK: - Epistemos MCP Server
// Receives JSON-RPC requests from the Hermes subprocess and dispatches
// to registered macOS tool handlers. Sends responses back via stdin pipe.
// Mirrors the Rust StdioServer in omega-mcp/src/transport.rs.

nonisolated(unsafe) private let mcpServerLog = Logger(subsystem: "com.epistemos", category: "EpistemosMCPServer")

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

    // MARK: - HTTP Transport for Large Payloads

    /// Maximum payload size in bytes before switching to HTTP transport.
    private static let stdioPayloadLimit = 50_000

    /// In-memory store for large payloads served via HTTP.
    private nonisolated(unsafe) var httpPayloadStore: [String: Data] = [:]
    /// The local HTTP server for serving large MCP payloads.
    private nonisolated(unsafe) var httpListener: MCPHttpListener?

    /// Start the HTTP transport server on a dynamic port.
    /// Returns the port number so Hermes can be informed.
    func startHttpTransport() -> Int? {
        let listener = MCPHttpListener { [weak self] payloadId in
            self?.lock.lock()
            let data = self?.httpPayloadStore.removeValue(forKey: payloadId)
            self?.lock.unlock()
            return data
        }
        guard let port = listener.start() else {
            mcpServerLog.warning("Failed to start MCP HTTP transport")
            return nil
        }
        lock.lock()
        httpListener = listener
        lock.unlock()
        mcpServerLog.info("MCP HTTP transport started on port \(port)")
        return port
    }

    /// If the response payload exceeds the stdio limit, store it and return
    /// a reference URL instead. Otherwise return the response unchanged.
    func wrapLargePayload(_ response: [String: AnyCodableValue]) -> [String: AnyCodableValue] {
        guard let data = try? JSONEncoder().encode(response),
              data.count > Self.stdioPayloadLimit,
              httpListener?.port != nil else {
            return response
        }

        let payloadId = UUID().uuidString
        lock.lock()
        httpPayloadStore[payloadId] = data
        lock.unlock()

        let port = httpListener?.port ?? 0
        return [
            "jsonrpc": .string("2.0"),
            "result": .dictionary([
                "_http_ref": .string("http://127.0.0.1:\(port)/mcp-payload/\(payloadId)"),
            ]),
            "id": response["id"] ?? .null,
        ]
    }

    func stopHttpTransport() {
        lock.lock()
        httpListener?.stop()
        httpListener = nil
        httpPayloadStore.removeAll()
        lock.unlock()
    }
}

// MARK: - MCPHttpListener

import Network

/// Minimal localhost HTTP server for serving large MCP payloads.
/// Uses Network.framework (NWListener) — zero external dependencies.
nonisolated final class MCPHttpListener: @unchecked Sendable {
    private let lock = NSLock()
    private var listener: NWListener?
    private let payloadFetcher: @Sendable (String) -> Data?
    private(set) var port: Int?

    init(payloadFetcher: @escaping @Sendable (String) -> Data?) {
        self.payloadFetcher = payloadFetcher
    }

    func start() -> Int? {
        do {
            let params = NWParameters.tcp
            params.allowLocalEndpointReuse = true
            let nwListener = try NWListener(using: params, on: .any)

            nwListener.stateUpdateHandler = { state in
                if case .failed(let error) = state {
                    mcpServerLog.error("MCP HTTP listener failed: \(error)")
                }
            }

            nwListener.newConnectionHandler = { [weak self] connection in
                self?.handleConnection(connection)
            }

            nwListener.start(queue: DispatchQueue(label: "com.epistemos.mcp-http"))

            // Wait briefly for the port to be assigned
            var attempts = 0
            while nwListener.port == nil && attempts < 10 {
                Thread.sleep(forTimeInterval: 0.05)
                attempts += 1
            }

            guard let assignedPort = nwListener.port?.rawValue else {
                nwListener.cancel()
                return nil
            }

            lock.lock()
            self.listener = nwListener
            self.port = Int(assignedPort)
            lock.unlock()

            return Int(assignedPort)
        } catch {
            mcpServerLog.error("Failed to create MCP HTTP listener: \(error)")
            return nil
        }
    }

    func stop() {
        lock.lock()
        listener?.cancel()
        listener = nil
        port = nil
        lock.unlock()
    }

    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: DispatchQueue(label: "com.epistemos.mcp-http-conn"))
        connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { [weak self] data, _, _, error in
            defer { connection.cancel() }
            guard let self, let data, error == nil else { return }

            guard let request = String(data: data, encoding: .utf8),
                  let pathLine = request.split(separator: "\r\n").first else {
                self.sendHttpResponse(connection: connection, status: 400, body: "Bad Request")
                return
            }

            // Parse: GET /mcp-payload/{id} HTTP/1.1
            let parts = pathLine.split(separator: " ")
            guard parts.count >= 2 else {
                self.sendHttpResponse(connection: connection, status: 400, body: "Bad Request")
                return
            }

            let path = String(parts[1])
            let prefix = "/mcp-payload/"
            guard path.hasPrefix(prefix) else {
                self.sendHttpResponse(connection: connection, status: 404, body: "Not Found")
                return
            }

            let payloadId = String(path.dropFirst(prefix.count))
            guard let payload = self.payloadFetcher(payloadId) else {
                self.sendHttpResponse(connection: connection, status: 404, body: "Payload expired")
                return
            }

            self.sendHttpResponse(connection: connection, status: 200, body: payload, contentType: "application/json")
        }
    }

    private func sendHttpResponse(connection: NWConnection, status: Int, body: String) {
        sendHttpResponse(connection: connection, status: status, body: Data(body.utf8), contentType: "text/plain")
    }

    private func sendHttpResponse(connection: NWConnection, status: Int, body: Data, contentType: String) {
        let statusText: String = switch status {
        case 200: "OK"
        case 400: "Bad Request"
        case 404: "Not Found"
        default: "Error"
        }
        let header = "HTTP/1.1 \(status) \(statusText)\r\nContent-Type: \(contentType)\r\nContent-Length: \(body.count)\r\nConnection: close\r\n\r\n"
        var responseData = Data(header.utf8)
        responseData.append(body)
        connection.send(content: responseData, completion: .contentProcessed { _ in
            connection.cancel()
        })
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
