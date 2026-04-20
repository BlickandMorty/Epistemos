import Foundation
import os

// MARK: - Archived ClaudeManagedRuntime
// This compatibility surface is retained for migration reference only. The
// shipping app has not yet moved its managed-agent connector work onto this
// abstraction, so the type stays archived and unavailable.

private let log = Logger(subsystem: "com.epistemos", category: "ClaudeManagedRuntime")

@available(*, unavailable, message: "Archived compatibility surface. Provider connectors should conform to the Overseer protocol instead of reviving this runtime shim.")
@MainActor
final class ClaudeManagedRuntime: AgentRuntime {
    let runtimeId = "claude-managed"
    let displayName = "Claude Managed Session"

    private let config: EpistemosConfig
    private var activeSessions: [String: URLSessionDataTask] = [:]

    /// CMA is available only when explicitly enabled AND an Anthropic API key exists.
    var isAvailable: Bool {
        config.claudeManagedSessionsEnabled && anthropicKeyExists
    }

    private var anthropicKeyExists: Bool {
        // Check Keychain for Anthropic API key
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.epistemos.apikeys",
            kSecAttrAccount as String: "anthropic",
            kSecReturnData as String: false,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        return SecItemCopyMatching(query as CFDictionary, nil) == errSecSuccess
    }

    init(config: EpistemosConfig) {
        self.config = config
    }

    func startSession(
        objective: String,
        config sessionConfig: AgentSessionConfig
    ) async throws -> String {
        guard isAvailable else {
            throw CMAError.notConfigured
        }

        let sessionId = UUID().uuidString
        log.info("ClaudeManagedRuntime: starting CMA session \(sessionId)")
        return sessionId
    }

    func cancelSession(_ sessionId: String) async {
        log.info("ClaudeManagedRuntime: cancelling CMA session \(sessionId)")
        activeSessions[sessionId]?.cancel()
        activeSessions.removeValue(forKey: sessionId)
    }

    func sessionEvents(_ sessionId: String) -> AsyncStream<AgentRuntimeEvent> {
        AsyncStream(bufferingPolicy: .bufferingNewest(2)) { continuation in
            continuation.yield(.sessionStarted(sessionId: sessionId))
            continuation.yield(.sessionFailed(error: "Archived Claude managed runtime surface"))
            continuation.finish()
        }
    }

    func sessionState(_ sessionId: String) -> AgentSessionState {
        if activeSessions[sessionId] != nil {
            return .running(turn: 0)
        }
        return .idle
    }

    // MARK: - Errors

    enum CMAError: LocalizedError {
        case notConfigured
        case apiError(String)
        case sseParseError(String)

        var errorDescription: String? {
            switch self {
            case .notConfigured:
                return "Claude Managed Sessions not configured — enable in Settings and add API key"
            case .apiError(let msg):
                return "CMA API error: \(msg)"
            case .sseParseError(let msg):
                return "CMA SSE parse error: \(msg)"
            }
        }
    }
}
