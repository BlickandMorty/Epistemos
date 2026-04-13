import Foundation

// MARK: - Archived Agent Runtime Surface
// This compatibility layer remains in source as migration reference only.
// The shipping app does not bootstrap it; live agent sessions route directly
// through ChatCoordinator / IMessageDriver and the low-level bridges.

/// Protocol that makes all agent backends interchangeable.
@available(*, unavailable, message: "Archived compatibility surface. The shipping app routes agent sessions directly through ChatCoordinator and LocalAgentLoop.")
@MainActor
protocol AgentRuntime: AnyObject, Sendable {
    /// Unique identifier for this runtime type.
    var runtimeId: String { get }

    /// Human-readable name shown in settings.
    var displayName: String { get }

    /// Whether this runtime is currently available (keys set, feature enabled, etc.).
    var isAvailable: Bool { get }

    /// Start an agent session. Returns a session ID.
    func startSession(
        objective: String,
        config: AgentSessionConfig
    ) async throws -> String

    /// Cancel a running session.
    func cancelSession(_ sessionId: String) async

    /// Subscribe to events from a running session.
    func sessionEvents(_ sessionId: String) -> AsyncStream<AgentRuntimeEvent>

    /// Query current session state (for UI display).
    func sessionState(_ sessionId: String) -> AgentSessionState
}

// MARK: - Session Config

/// Unified session configuration — works for all backends.
@available(*, unavailable, message: "Archived compatibility surface. The shipping app routes agent sessions directly through ChatCoordinator and LocalAgentLoop.")
struct AgentSessionConfig: Sendable {
    var maxTurns: Int = 50
    var maxCostUSD: Double?
    var enableBash: Bool = false
    var enableWebSearch: Bool = true
    var enableVaultWrite: Bool = false
    var additionalContext: String = ""
    var runtimePreference: RuntimePreference = .localFirst

    enum RuntimePreference: String, Sendable, Codable {
        case localFirst   // prefer local, fall back to cloud
        case cloudFirst   // prefer cloud, fall back to local
        case localOnly    // never use cloud
        case cloudOnly    // never use local
    }
}

// MARK: - Agent Events

/// Unified event stream — identical schema regardless of backend.
@available(*, unavailable, message: "Archived compatibility surface. The shipping app routes agent sessions directly through ChatCoordinator and LocalAgentLoop.")
enum AgentRuntimeEvent: Sendable {
    case sessionStarted(sessionId: String)
    case turnStarted(turn: Int)
    case tokenEmitted(token: String)
    case thinkingEmitted(token: String)
    case toolCallStarted(toolName: String, args: String)
    case toolCallCompleted(toolName: String, result: String, durationMs: Int)
    case approvalRequired(toolName: String, args: String, riskLevel: String)
    case budgetWarning(spentUSD: Double, limitUSD: Double)
    case turnCompleted(turn: Int, content: String)
    case sessionCompleted(totalTurns: Int, totalCostUSD: Double)
    case sessionFailed(error: String)
    case sessionCancelled
}

// MARK: - Agent Session State

/// Simplified session state for UI display.
@available(*, unavailable, message: "Archived compatibility surface. The shipping app routes agent sessions directly through ChatCoordinator and LocalAgentLoop.")
enum AgentSessionState: Sendable {
    case idle
    case running(turn: Int)
    case pausedForApproval(toolName: String)
    case completed(turns: Int)
    case failed(error: String)
    case cancelled
}

// MARK: - Runtime Registry

/// Manages available runtimes and provides the active one.
@available(*, unavailable, message: "Archived compatibility surface. The shipping app routes agent sessions directly through ChatCoordinator and LocalAgentLoop.")
@MainActor
@Observable
final class AgentRuntimeRegistry {
    private(set) var runtimes: [any AgentRuntime] = []
    var activeRuntimeId: String = "local-rust"

    var activeRuntime: (any AgentRuntime)? {
        runtimes.first { $0.runtimeId == activeRuntimeId }
    }

    var availableRuntimes: [any AgentRuntime] {
        runtimes.filter(\.isAvailable)
    }

    func register(_ runtime: any AgentRuntime) {
        runtimes.append(runtime)
    }

    func setActive(_ runtimeId: String) {
        guard runtimes.contains(where: { $0.runtimeId == runtimeId }) else { return }
        activeRuntimeId = runtimeId
    }
}
