import Foundation
import os

// MARK: - LocalRustRuntime
// Wraps the existing Rust agent_core FFI layer as an AgentRuntime.
// This is the default runtime — runs entirely on-device.

private let log = Logger(subsystem: "com.epistemos", category: "LocalRustRuntime")

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

        // The actual implementation delegates to the existing Rust FFI bridge.
        // This is a placeholder that emits the expected event sequence.
        // Wire to the real bridge via StreamingDelegate callbacks → AgentRuntimeEvent mapping.
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

    /// Called by StreamingDelegate to forward Rust events into the unified stream.
    func emitEvent(_ sessionId: String, event: AgentRuntimeEvent) {
        activeSessions[sessionId]?.yield(event)
    }
}
