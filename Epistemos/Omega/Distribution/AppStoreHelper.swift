import Foundation
import os
import ServiceManagement

// MARK: - App Store Distribution Helper

/// Manages the double-helper App Store distribution pattern:
///
/// 1. Epistemos.app (SANDBOXED) — SwiftUI, TCC prompts, App Store distribution
/// 2. EpistemosGateway (NON-SANDBOXED) — Rust automation, AX tree, CGEvent
///
/// Communication: Unix Domain Socket (mode 0600, HMAC auth, 30s token TTL)
/// Registration: SMAppService for login item / helper management
///
/// This file contains the Swift-side helper management.
/// The actual gateway binary lives in a separate target (Ω17 full implementation).
@MainActor @Observable
final class AppStoreHelper {
    private let log = Logger(subsystem: "com.epistemos.omega", category: "AppStoreHelper")

    /// Whether the helper is registered as a login item.
    private(set) var isHelperRegistered: Bool = false

    /// Whether the helper process is currently running.
    private(set) var isHelperRunning: Bool = false

    /// Connection status to the gateway.
    private(set) var connectionStatus: GatewayConnectionStatus = .disconnected

    /// The Unix Domain Socket path.
    let socketPath: String = {
        let support = FoundationSafety.userApplicationSupportDirectory()
        return support.appendingPathComponent("Epistemos/gateway.sock").path
    }()

    // MARK: - Helper Registration

    /// Register the EpistemosGateway helper via SMAppService.
    /// This presents a system dialog asking the user to allow the helper.
    func registerHelper() {
        let service = SMAppService.loginItem(identifier: "com.epistemos.gateway")
        do {
            try service.register()
            isHelperRegistered = true
            log.info("Gateway helper registered as login item")
        } catch {
            log.error("Failed to register gateway helper: \(error.localizedDescription)")
            isHelperRegistered = false
        }
    }

    /// Unregister the helper.
    func unregisterHelper() {
        let service = SMAppService.loginItem(identifier: "com.epistemos.gateway")
        do {
            try service.unregister()
            isHelperRegistered = false
            log.info("Gateway helper unregistered")
        } catch {
            log.error("Failed to unregister gateway helper: \(error.localizedDescription)")
        }
    }

    /// Check if the helper is currently registered.
    func checkRegistration() {
        let service = SMAppService.loginItem(identifier: "com.epistemos.gateway")
        isHelperRegistered = service.status == .enabled
    }

    // MARK: - Gateway Connection

    /// Connect to the EpistemosGateway via Unix Domain Socket.
    /// The gateway must be running (launched as login item or manually).
    func connect() async {
        connectionStatus = .connecting

        // Check socket exists
        guard FileManager.default.fileExists(atPath: socketPath) else {
            connectionStatus = .disconnected
            log.warning("Gateway socket not found at \(self.socketPath)")
            return
        }

        // Generate HMAC auth token
        let token = generateAuthToken()

        // Connect via socket
        do {
            let connection = try await GatewayConnection.connect(
                socketPath: socketPath,
                authToken: token
            )
            connectionStatus = .connected(connection)
            isHelperRunning = true
            log.info("Connected to EpistemosGateway")
        } catch {
            connectionStatus = .error(error.localizedDescription)
            isHelperRunning = false
            log.error("Gateway connection failed: \(error.localizedDescription)")
        }
    }

    /// Disconnect from the gateway.
    func disconnect() {
        if case .connected(let conn) = connectionStatus {
            conn.close()
        }
        connectionStatus = .disconnected
        isHelperRunning = false
    }

    // MARK: - IPC Protocol

    /// Send a tool execution request to the gateway.
    /// The gateway runs the Rust omega-ax/omega-mcp tools outside the sandbox.
    func executeViaGateway(toolName: String, argumentsJson: String) async throws -> String {
        guard case .connected(let conn) = connectionStatus else {
            throw GatewayError.notConnected
        }

        let request = GatewayRequest(
            method: "tool/execute",
            params: ["tool": toolName, "arguments": argumentsJson],
            timestamp: Date()
        )

        return try await conn.send(request)
    }

    // MARK: - Auth

    private func generateAuthToken() -> String {
        // HMAC-SHA256 with shared secret from Keychain
        // For now, use a timestamp-based token (30s TTL)
        let timestamp = Int(Date().timeIntervalSince1970)
        let payload = "epistemos-gateway-\(timestamp)"
        // In production: HMAC with Keychain-stored secret
        return payload
    }
}

// MARK: - Types

enum GatewayConnectionStatus {
    case disconnected
    case connecting
    case connected(GatewayConnection)
    case error(String)

    var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }
}

/// Placeholder for the Unix Domain Socket connection.
/// Full implementation in Ω17 with proper socket I/O.
final class GatewayConnection: Sendable {
    private let socketPath: String

    private init(socketPath: String) {
        self.socketPath = socketPath
    }

    static func connect(socketPath: String, authToken: String) async throws -> GatewayConnection {
        // TODO: Actual UDS connection + auth handshake
        throw GatewayError.helperNotInstalled
    }

    func send(_ request: GatewayRequest) async throws -> String {
        throw GatewayError.notConnected
    }

    func close() {}
}

struct GatewayRequest: Sendable {
    let method: String
    let params: [String: String]
    let timestamp: Date
}

enum GatewayError: Error, LocalizedError {
    case notConnected
    case helperNotInstalled
    case authFailed
    case timeout

    var errorDescription: String? {
        switch self {
        case .notConnected: "Not connected to EpistemosGateway"
        case .helperNotInstalled: "EpistemosGateway helper not installed"
        case .authFailed: "Authentication with gateway failed"
        case .timeout: "Gateway request timed out"
        }
    }
}
