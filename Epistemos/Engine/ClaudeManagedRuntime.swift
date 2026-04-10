import Foundation
import os

// MARK: - ClaudeManagedRuntime
// Optional cloud backend wrapping Claude Managed Agents API.
// Uses raw URLSession — NO Swift SDK (per CLAUDE.md non-negotiable).
//
// This is EXPERIMENTAL and behind a settings toggle.
// Sessions run in Anthropic's cloud infrastructure (~$0.08/session-hour active).
//
// Two vault integration patterns (from new3.md research):
// 1. Live tool calls (preferred): PKM ops as custom tools, agent pauses, Swift executes locally
// 2. Snapshot and merge (privacy): export subset → upload → agent processes → download → merge

private let log = Logger(subsystem: "com.epistemos", category: "ClaudeManagedRuntime")

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

        // TODO: Implement actual CMA API call when endpoint is stable
        // POST https://api.anthropic.com/v1/sessions
        // Body: { model, system, tools, max_tokens, ... }
        // Returns: { session_id, status: "running" }
        //
        // For now, this is a placeholder that logs the attempt.
        // The CMA API is in private beta and endpoints may change.

        log.warning("ClaudeManagedRuntime: CMA API integration is experimental — session \(sessionId) not yet wired to live API")
        return sessionId
    }

    func cancelSession(_ sessionId: String) async {
        log.info("ClaudeManagedRuntime: cancelling CMA session \(sessionId)")
        activeSessions[sessionId]?.cancel()
        activeSessions.removeValue(forKey: sessionId)

        // TODO: DELETE https://api.anthropic.com/v1/sessions/{id}
    }

    func sessionEvents(_ sessionId: String) -> AsyncStream<AgentRuntimeEvent> {
        // TODO: Implement SSE streaming from CMA
        // GET https://api.anthropic.com/v1/sessions/{id}/events
        // Parse SSE stream → map to AgentRuntimeEvent enum
        AsyncStream { continuation in
            continuation.yield(.sessionStarted(sessionId: sessionId))
            continuation.yield(.sessionFailed(error: "CMA API integration not yet active — use Local runtime"))
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
