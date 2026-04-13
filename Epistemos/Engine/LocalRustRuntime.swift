import Foundation
import os

// MARK: - Archived LocalRustRuntime
// Kept only as a migration reference while the shipping app uses the
// lower-level session bridges directly.

private let log = Logger(subsystem: "com.epistemos", category: "LocalRustRuntime")

@available(*, unavailable, message: "Archived compatibility surface. Use ChatCoordinator and the low-level Rust bridge for shipping agent sessions.")
@MainActor
final class LocalRustRuntime: AgentRuntime {
    let runtimeId = "local-rust"
    let displayName = "Local (Rust)"

    var isAvailable: Bool {
        // Local runtime is always available when the app is running
        true
    }

    private var activeSessions: [String: AsyncStream<AgentRuntimeEvent>.Continuation] = [:]

    func startSession(
        objective: String,
        config: AgentSessionConfig
    ) async throws -> String {
        let sessionId = UUID().uuidString
        log.info("LocalRustRuntime: starting session \(sessionId)")
        return sessionId
    }

    func cancelSession(_ sessionId: String) async {
        log.info("LocalRustRuntime: cancelling session \(sessionId)")
        activeSessions[sessionId]?.finish()
        activeSessions.removeValue(forKey: sessionId)
    }

    func sessionEvents(_ sessionId: String) -> AsyncStream<AgentRuntimeEvent> {
        AsyncStream { continuation in
            activeSessions[sessionId] = continuation
            continuation.onTermination = { @Sendable [weak self] _ in
                Task { @MainActor in
                    self?.activeSessions.removeValue(forKey: sessionId)
                }
            }
        }
    }

    func sessionState(_ sessionId: String) -> AgentSessionState {
        if activeSessions[sessionId] != nil {
            return .running(turn: 0)
        }
        return .idle
    }

    func emitEvent(_ sessionId: String, event: AgentRuntimeEvent) {
        activeSessions[sessionId]?.yield(event)
    }
}
