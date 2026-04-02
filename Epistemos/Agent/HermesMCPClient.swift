import Foundation
import os

// MARK: - Hermes MCP Client
// Sends JSON-RPC requests to the Hermes subprocess over stdin
// and correlates responses received on stdout.
// Protocol matches omega-mcp/src/transport.rs (newline-delimited JSON-RPC 2.0).

private nonisolated let mcpClientLog = Logger(subsystem: "com.epistemos", category: "HermesMCPClient")

// MARK: - Errors

enum HermesMCPError: LocalizedError {
    case notConnected
    case requestTimeout(method: String, timeoutSeconds: Double)
    case serverError(code: Int, message: String)
    case invalidResponse(String)
    case encodingError

    var errorDescription: String? {
        switch self {
        case .notConnected: "MCP client not connected to Hermes subprocess"
        case .requestTimeout(let method, let timeout): "MCP request '\(method)' timed out after \(timeout)s"
        case .serverError(let code, let msg): "MCP server error \(code): \(msg)"
        case .invalidResponse(let detail): "Invalid MCP response: \(detail)"
        case .encodingError: "Failed to encode MCP request"
        }
    }
}

// MARK: - JSON-RPC Types (Swift side)

private nonisolated struct MCPJsonRpcRequest: Encodable, Sendable {
    let jsonrpc: String = "2.0"
    let method: String
    let params: [String: AnyCodableValue]
    let id: Int
}

private nonisolated struct MCPJsonRpcResponse: Decodable, Sendable {
    let jsonrpc: String
    let result: AnyCodableValue?
    let error: MCPJsonRpcError?
    let id: Int?
}

private nonisolated struct MCPJsonRpcError: Decodable, Sendable {
    let code: Int
    let message: String
}

// MARK: - MCP Client

final class HermesMCPClient: @unchecked Sendable {
    private let lock = NSLock()
    private nonisolated(unsafe) var nextId: Int = 1
    private nonisolated(unsafe) var pendingRequests: [Int: CheckedContinuation<AnyCodableValue, any Error>] = [:]
    private nonisolated(unsafe) weak var subprocessManager: HermesSubprocessManager?
    private let defaultTimeout: Duration

    init(subprocessManager: HermesSubprocessManager, defaultTimeout: Duration = .seconds(10)) {
        self.subprocessManager = subprocessManager
        self.defaultTimeout = defaultTimeout
    }

    /// Connect to the subprocess's stdout to receive responses.
    /// Call after subprocess launch.
    @MainActor
    func attach() {
        subprocessManager?.setRequestHandler { [weak self] jsonLine in
            self?.handleIncomingLine(jsonLine)
        }
        subprocessManager?.setDisconnectHandler { [weak self] in
            self?.cancelAll()
        }
    }

    /// Send an MCP request and await the response.
    func send(
        method: String,
        params: [String: AnyCodableValue] = [:],
        timeout: Duration? = nil
    ) async throws -> AnyCodableValue {
        guard let manager = subprocessManager else {
            throw HermesMCPError.notConnected
        }

        let requestId = generateId()
        let request = MCPJsonRpcRequest(method: method, params: params, id: requestId)

        guard let data = try? JSONEncoder().encode(request),
              let json = String(data: data, encoding: .utf8) else {
            throw HermesMCPError.encodingError
        }

        let effectiveTimeout = timeout ?? defaultTimeout

        return try await withThrowingTaskGroup(of: AnyCodableValue.self) { group in
            group.addTask {
                try await withTaskCancellationHandler {
                    try await withCheckedThrowingContinuation { continuation in
                        guard !Task.isCancelled else {
                            continuation.resume(throwing: CancellationError())
                            return
                        }

                        self.registerPending(id: requestId, continuation: continuation)

                        do {
                            try manager.writeLine(json)
                            mcpClientLog.debug("MCP request sent: \(method) id=\(requestId)")
                        } catch {
                            self.removePending(id: requestId, resumingWith: error)
                        }
                    }
                } onCancel: {
                    self.removePending(id: requestId, resumingWith: CancellationError())
                }
            }

            group.addTask {
                try await Task.sleep(for: effectiveTimeout)
                let timeoutError = HermesMCPError.requestTimeout(method: method, timeoutSeconds: effectiveTimeout.totalSeconds)
                self.removePending(id: requestId, resumingWith: timeoutError)
                throw timeoutError
            }

            // Return whichever finishes first
            let result = try await group.next()
            group.cancelAll()
            guard let result else {
                throw HermesMCPError.invalidResponse("no result from task group")
            }
            return result
        }
    }

    /// Send an MCP notification (no response expected).
    func notify(method: String, params: [String: AnyCodableValue] = [:]) throws {
        guard let manager = subprocessManager else {
            throw HermesMCPError.notConnected
        }

        struct Notification: Encodable {
            let jsonrpc: String = "2.0"
            let method: String
            let params: [String: AnyCodableValue]
        }

        let notification = Notification(method: method, params: params)
        guard let data = try? JSONEncoder().encode(notification),
              let json = String(data: data, encoding: .utf8) else {
            throw HermesMCPError.encodingError
        }

        try manager.writeLine(json)
        mcpClientLog.debug("MCP notification sent: \(method)")
    }

    // MARK: - Convenience Methods

    func listTools() async throws -> AnyCodableValue {
        try await send(method: "tools/list", timeout: .seconds(5))
    }

    func callTool(name: String, arguments: [String: AnyCodableValue]) async throws -> AnyCodableValue {
        try await send(method: "tools/call", params: [
            "name": .string(name),
            "arguments": .dictionary(arguments),
        ])
    }

    func ping() async throws -> AnyCodableValue {
        try await send(method: "ping", timeout: .seconds(5))
    }

    // MARK: - Internal

    private nonisolated func generateId() -> Int {
        lock.lock()
        defer { lock.unlock() }
        let id = nextId
        nextId += 1
        return id
    }

    private nonisolated func registerPending(id: Int, continuation: CheckedContinuation<AnyCodableValue, any Error>) {
        lock.lock()
        defer { lock.unlock() }
        pendingRequests[id] = continuation
    }

    /// Remove a pending request, resuming its continuation with the given error if still present.
    /// This prevents continuation leaks when the timeout fires before a response arrives.
    private nonisolated func removePending(id: Int, resumingWith error: (any Error)? = nil) {
        lock.lock()
        let continuation = pendingRequests.removeValue(forKey: id)
        lock.unlock()

        if let continuation, let error {
            continuation.resume(throwing: error)
        }
        // If no error provided and continuation exists, the response handler
        // will find it already removed and skip — this is the expected race.
    }

    nonisolated func handleIncomingLine(_ jsonLine: String) {
        guard let data = jsonLine.data(using: .utf8) else { return }

        // Try parsing as a response (has id + result/error)
        if let response = try? JSONDecoder().decode(MCPJsonRpcResponse.self, from: data),
           let responseId = response.id {
            lock.lock()
            let continuation = pendingRequests.removeValue(forKey: responseId)
            lock.unlock()

            if let continuation {
                if let error = response.error {
                    continuation.resume(throwing: HermesMCPError.serverError(
                        code: error.code, message: error.message
                    ))
                } else if let result = response.result {
                    continuation.resume(returning: result)
                } else {
                    continuation.resume(returning: .null)
                }
            } else {
                mcpClientLog.debug("Received response for unknown request id=\(responseId)")
            }
            return
        }

        // Not a response — might be an incoming request from Hermes
        // (handled by EpistemosMCPServer, not here)
        mcpClientLog.debug("MCP line not a response, forwarding to server handler")
    }

    /// Cancel all pending requests (call on disconnect).
    nonisolated func cancelAll() {
        lock.lock()
        let pending = pendingRequests
        pendingRequests.removeAll()
        lock.unlock()

        for (_, continuation) in pending {
            continuation.resume(throwing: HermesMCPError.notConnected)
        }
    }

    var pendingRequestCountForTesting: Int {
        lock.lock()
        defer { lock.unlock() }
        return pendingRequests.count
    }
}

// MARK: - Duration Extension

extension Duration {
    fileprivate nonisolated var totalSeconds: Double {
        let (seconds, attoseconds) = components
        return Double(seconds) + Double(attoseconds) * 1e-18
    }
}

// MARK: - AnyCodableValue

/// Type-safe JSON value for MCP request/response params.
/// Avoids `Any` while supporting arbitrary JSON structures.
enum AnyCodableValue: Sendable, Equatable {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([AnyCodableValue])
    case dictionary([String: AnyCodableValue])
}

extension AnyCodableValue: Encodable {
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null: try container.encodeNil()
        case .bool(let v): try container.encode(v)
        case .int(let v): try container.encode(v)
        case .double(let v): try container.encode(v)
        case .string(let v): try container.encode(v)
        case .array(let v): try container.encode(v)
        case .dictionary(let v): try container.encode(v)
        }
    }
}

extension AnyCodableValue: Decodable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let v = try? container.decode(Bool.self) {
            self = .bool(v)
        } else if let v = try? container.decode(Int.self) {
            self = .int(v)
        } else if let v = try? container.decode(Double.self) {
            self = .double(v)
        } else if let v = try? container.decode(String.self) {
            self = .string(v)
        } else if let v = try? container.decode([AnyCodableValue].self) {
            self = .array(v)
        } else if let v = try? container.decode([String: AnyCodableValue].self) {
            self = .dictionary(v)
        } else {
            self = .null
        }
    }
}
